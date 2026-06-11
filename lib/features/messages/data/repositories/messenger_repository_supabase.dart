import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:uuid/uuid.dart';

import '../../../../core/crypto/base64url.dart';
import '../../../../core/crypto/encrypted_blob_store.dart';
import '../../../../core/crypto/profile_cipher.dart';
import '../../../../core/crypto/ratchet_engine.dart';
import '../../../../core/crypto/sealed_payload.dart';
import '../../../../core/storage/identity_vault.dart';
import '../../../../core/storage/local_messenger_db.dart';
import '../../../../core/supabase/pg_bytea.dart';
import '../../../../core/supabase/realtime_relay.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/chat_summary.dart';
import '../../domain/entities/current_user.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_hit.dart';
import '../../domain/entities/message_status.dart';
import '../../domain/entities/message_type.dart';
import '../../domain/entities/reply_preview.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/messenger_repository.dart';

class MessengerRepositorySupabase implements MessengerRepository {
  MessengerRepositorySupabase({
    required SupabaseClient client,
    required String accountId,
    required String deviceId,
    required RatchetEngine ratchet,
    required RealtimeRelay relay,
    SettingsRepository? settings,
    IdentityVault? vault,
  }) : _client = client,
       _selfId = accountId,
       _deviceId = deviceId,
       _ratchet = ratchet,
       _relay = relay,
       _settings = settings,
       _vault = vault ?? IdentityVault(),
       _blobStore = EncryptedBlobStore(client: client);

  final SupabaseClient _client;
  final String _selfId;
  final String _deviceId;
  final RatchetEngine _ratchet;
  final RealtimeRelay _relay;
  final SettingsRepository? _settings;
  final IdentityVault _vault;
  final EncryptedBlobStore _blobStore;
  late final _db = LocalMessengerDb.forAccount(_selfId);
  final _uuid = const Uuid();
  CurrentUser? _me;

  Timer? _presenceTimer;
  StreamSubscription<Map<String, dynamic>>? _envelopeSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _presenceRelaySub;
  final Map<String, bool> _typingByPeer = <String, bool>{};

  final StreamController<String> _presenceEventCtrl =
      StreamController<String>.broadcast();

  final Map<String, Uint8List> _peerAvatarBytes = <String, Uint8List>{};

  final Set<String> _announcedTo = <String>{};

  Map<String, dynamic>? _meSnapshot;
  final StreamController<TypingPing> _typingCtrl =
      StreamController<TypingPing>.broadcast();

  final StreamController<IncomingMessage> _incomingCtrl =
      StreamController<IncomingMessage>.broadcast();
  Stream<IncomingMessage> get incomingMessages => _incomingCtrl.stream;

  String _self() => _selfId;
  String _device() => _deviceId;

  void startPresence() {
    _presenceTimer?.cancel();
    unawaited(_reportPresence());
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _reportPresence(),
    );
  }

  Future<void> _reportPresence() async {
    try {
      await _client.rpc<void>('report_presence');
    } catch (_) {}
  }

  Future<void> ensureRelayStarted() async {
    startPresence();
    _relay.connect();
    await _envelopeSub?.cancel();
    _envelopeSub = _relay.envelopes.listen((row) {
      unawaited(_ingestEnvelope(_self(), row));
    });
    await _typingSub?.cancel();
    _typingSub = _relay.typing.listen((row) {
      final peer = row['peerAccountId'] as String?;
      if (peer == null) return;
      final isTyping = row['isTyping'] as bool? ?? false;
      _typingByPeer[peer] = isTyping;
      if (!_typingCtrl.isClosed) {
        _typingCtrl.add(TypingPing(peerAccountId: peer, isTyping: isTyping));
      }
    });
    await _presenceRelaySub?.cancel();
    _presenceRelaySub = _relay.presence.listen((row) {
      final acc = row['accountId'] as String?;
      if (acc != null && !_presenceEventCtrl.isClosed) {
        _presenceEventCtrl.add(acc);
      }
    });
    await _pullPending(_self());
  }

  void dispose() {
    _presenceTimer?.cancel();
    _envelopeSub?.cancel();
    _typingSub?.cancel();
    _presenceRelaySub?.cancel();
    _typingCtrl.close();
    _presenceEventCtrl.close();
    _incomingCtrl.close();
  }

  static String _previewFor(Message message) {
    final text = message.text?.trim() ?? '';
    if (text.isNotEmpty) return text;
    switch (message.type) {
      case MessageType.image:
      case MessageType.gif:
      case MessageType.sticker:
        return '📷 photo';
      case MessageType.video:
        return '🎬 video';
      case MessageType.voice:
        return '🎤 voice message';
      case MessageType.audio:
        return '🎵 audio';
      case MessageType.file:
        return '📎 file';
      case MessageType.location:
        return '📍 location';
      case MessageType.text:
        return 'New message';
    }
  }

  Future<void> _pullPending(String self) async {
    final List<dynamic> rows;
    try {
      rows = await _client.rpc<List<dynamic>>(
        'fetch_pending_envelopes',
        params: <String, dynamic>{'p_limit': 200},
      );
    } catch (_) {
      return;
    }
    for (final raw in rows) {
      if (raw is Map<String, dynamic>) {
        await _ingestEnvelope(self, raw);
      }
    }
  }

  Future<void> _ingestEnvelope(String self, Map<String, dynamic> row) async {
    final envelopeId = (row['id'] ?? row['envelopeId']).toString();
    final cipherRaw = row['ciphertext'] as String?;
    if (cipherRaw == null) return;
    final cipherB64Url = _toBase64Url(cipherRaw);

    try {
      final sealed = await _ratchet.decryptInbound(cipherB64Url);
      final senderId = sealed.senderAccountId;
      if (senderId == self) return;
      if (_settings?.isBlocked(senderId) ?? false) {
        await _ack(envelopeId);
        return;
      }
      final chatId = LocalMessengerDb.dmChatId(self, senderId);
      final body = sealed.body;
      if (body['type'] == 'profile') {
        final displayName = body['displayName'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          final avatarJson = body['avatar'];
          await _db.applyPeerProfile(
            accountId: senderId,
            displayName: displayName,
            username: body['username'] as String?,
            avatar: avatarJson is Map<String, dynamic>
                ? EncryptedBlobRef.fromJson(avatarJson)
                : null,
            bio: body['bio'] as String?,
          );
        }
        unawaited(_announceProfileTo(senderId));
        await _ack(envelopeId);
        return;
      }
      if (body['type'] == 'reaction') {
        final messageId = body['messageId'] as String?;
        final emoji = body['emoji'] as String?;
        if (messageId != null && emoji != null) {
          await _db.toggleReaction(
            chatId: chatId,
            messageId: messageId,
            userId: senderId,
            emoji: emoji,
          );
        }
        await _ack(envelopeId);
        return;
      }
      if (body['type'] == 'edit') {
        final messageId = body['messageId'] as String?;
        final text = body['text'] as String?;
        if (messageId != null && text != null) {
          await _db.updateMessageText(chatId, messageId, text);
        }
        await _ack(envelopeId);
        return;
      }
      if (body['type'] == 'delete') {
        final messageId = body['messageId'] as String?;
        if (messageId != null) await _db.deleteMessage(chatId, messageId);
        await _ack(envelopeId);
        return;
      }
      if (body['type'] == 'read') {
        await _db.markOutgoingRead(chatId, self);
        await _ack(envelopeId);
        return;
      }
      if (body['type'] == 'pin') {
        await _db.setPinnedMessageId(chatId, body['messageId'] as String?);
        await _ack(envelopeId);
        return;
      }
      if (body['type'] == 'deleteChat') {
        await _db.deleteChat(chatId);
        await _ack(envelopeId);
        return;
      }
      final msg = _messageFromSealed(sealed);
      await _db.insertMessage(msg, chatId: chatId);
      final summaries = await _db.chatSummaries(self);
      var prev = 0;
      var muted = false;
      for (final s in summaries) {
        if (s.id == chatId) {
          prev = s.unreadCount;
          muted = s.isMuted;
          break;
        }
      }
      await _db.setUnread(chatId, prev + 1);
      if (!muted && !_incomingCtrl.isClosed) {
        final peer = await _db.peer(senderId);
        _incomingCtrl.add(
          IncomingMessage(
            chatId: chatId,
            senderName: (peer?.name.trim().isNotEmpty ?? false)
                ? peer!.name
                : 'New message',
            preview: _previewFor(msg),
          ),
        );
      }
    } catch (_) {
      return;
    }

    await _ack(envelopeId);
  }

  Future<void> _ack(String envelopeId) async {
    try {
      await _client.rpc<void>(
        'ack_envelopes',
        params: <String, dynamic>{
          'p_ids': <String>[envelopeId],
        },
      );
    } catch (_) {}
  }

  Message _messageFromSealed(SealedMessagePayload sealed) {
    final body = sealed.body;
    final type = _typeFromName(body['type'] as String?);
    final attJson = body['attachment'];
    return Message(
      id: sealed.messageId.isNotEmpty ? sealed.messageId : _uuid.v4(),
      senderId: sealed.senderAccountId,
      type: type,
      timestamp: DateTime.now().toUtc(),
      text: body['text'] as String? ?? body['caption'] as String?,
      attachment: attJson is Map<String, dynamic>
          ? Attachment.fromJson(attJson)
          : null,
      status: MessageStatus.delivered,
      noForward: body['noForward'] == true,
    );
  }

  MessageType _typeFromName(String? name) {
    if (name == null) return MessageType.text;
    for (final t in MessageType.values) {
      if (t.name == name) return t;
    }
    return MessageType.text;
  }

  @override
  Future<Message> sendMedia({
    required String chatId,
    required MessageType type,
    required Uint8List bytes,
    String? caption,
    String? fileName,
    String? mime,
    int? width,
    int? height,
    int? durationMs,
    ReplyPreview? replyTo,
  }) async {
    final peerId = await _peerFromChat(chatId);
    if (_settings?.isBlocked(peerId) ?? false) {
      throw const SendMessageException(
        'Cannot message a blocked user',
        recoverable: false,
      );
    }
    unawaited(_announceProfileTo(peerId));
    final self = _self();
    final messageId = _uuid.v4();
    final EncryptedBlobRef ref;
    try {
      ref = await _blobStore.upload(bytes, mime: mime);
    } catch (_) {
      throw const SendMessageException(
        'Couldn’t upload media. Check your connection and try again.',
      );
    }
    final attachment = Attachment(
      objectKey: ref.objectKey,
      blobKey: ref.keyB64,
      nonce: ref.nonceB64,
      size: ref.size,
      mime: mime,
      fileName: fileName,
      width: width,
      height: height,
      durationMs: durationMs,
    );
    final noForward = await _noForward();
    final sealed = SealedMessagePayload(
      messageId: messageId,
      senderAccountId: self,
      senderDeviceId: _device(),
      body: <String, dynamic>{
        'type': type.name,
        'caption': ?caption,
        'replyToId': ?replyTo?.messageId,
        if (noForward) 'noForward': true,
        'attachment': attachment.toJson(),
      },
    );
    try {
      await _sendSealed(peerAccountId: peerId, payload: sealed);
    } catch (e) {
      await _blobStore.remove(ref.objectKey);
      final noBundle = e.toString().contains('No libsignal bundle');
      throw SendMessageException(
        noBundle
            ? 'This person hasn’t set up secure messaging yet, so your media can’t be delivered.'
            : 'Couldn’t send your media. Check your connection and try again.',
        recoverable: !noBundle,
      );
    }
    final msg = Message(
      id: messageId,
      senderId: self,
      type: type,
      timestamp: DateTime.now().toUtc(),
      text: caption,
      attachment: attachment,
      status: MessageStatus.sent,
      noForward: noForward,
    );
    await _insertLocalSent(peerAccountId: peerId, message: msg);
    return msg;
  }

  @override
  Future<Message> sendLocation({
    required String chatId,
    required double lat,
    required double lng,
    String? caption,
  }) async {
    final peerId = await _peerFromChat(chatId);
    if (_settings?.isBlocked(peerId) ?? false) {
      throw const SendMessageException(
        'Cannot message a blocked user',
        recoverable: false,
      );
    }
    unawaited(_announceProfileTo(peerId));
    final self = _self();
    final messageId = _uuid.v4();
    final attachment = Attachment(lat: lat, lng: lng);
    final sealed = SealedMessagePayload(
      messageId: messageId,
      senderAccountId: self,
      senderDeviceId: _device(),
      body: <String, dynamic>{
        'type': MessageType.location.name,
        'caption': ?caption,
        'attachment': attachment.toJson(),
      },
    );
    try {
      await _sendSealed(peerAccountId: peerId, payload: sealed);
    } catch (e) {
      final noBundle = e.toString().contains('No libsignal bundle');
      throw SendMessageException(
        noBundle
            ? 'This person hasn’t set up secure messaging yet.'
            : 'Couldn’t send your location.',
        recoverable: !noBundle,
      );
    }
    final msg = Message(
      id: messageId,
      senderId: self,
      type: MessageType.location,
      timestamp: DateTime.now().toUtc(),
      text: caption,
      attachment: attachment,
      status: MessageStatus.sent,
    );
    await _insertLocalSent(peerAccountId: peerId, message: msg);
    return msg;
  }

  @override
  Future<Uint8List> downloadMedia(Attachment attachment) {
    if (!attachment.hasBlob) {
      throw const SendMessageException(
        'This attachment has no downloadable content.',
      );
    }
    return _blobStore.download(
      EncryptedBlobRef(
        objectKey: attachment.objectKey!,
        keyB64: attachment.blobKey!,
        nonceB64: attachment.nonce!,
        size: attachment.size ?? 0,
        mime: attachment.mime,
      ),
    );
  }

  Future<void> _sendSealed({
    required String peerAccountId,
    required SealedMessagePayload payload,
    bool control = false,
  }) async {
    if (peerAccountId == _self()) return;
    final cipherB64Url = await _ratchet.encrypt(
      peerAccountId: peerAccountId,
      payload: payload,
    );
    final cipherBytes = decodeBase64Url(cipherB64Url);
    await _client.rpc<dynamic>(
      'send_envelope',
      params: <String, dynamic>{
        'p_recipient': peerAccountId,
        'p_recipient_device': null,
        'p_envelope_type': control ? 2 : 1,
        'p_ciphertext': bytesToPgHex(cipherBytes),
        'p_client_message_id': _uuid.v4(),
      },
    );
  }

  Future<Map<String, dynamic>> _mySnapshot() async {
    if (_meSnapshot != null) return _meSnapshot!;
    final material = await _vault.loadOrThrow();
    final rows = await _client
        .from('accounts')
        .select('id, username, profile_ciphertext')
        .eq('id', _self())
        .limit(1);
    final raw = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    final cipher = await ProfileCipher.fromIdentitySeed(material.identitySeed);
    final profile = await cipher.decrypt(raw['profile_ciphertext'] as String?);
    final avatar = profile['avatar'];
    final username = raw['username'] as String?;
    final bio = profile['bio'] as String?;
    return _meSnapshot = <String, dynamic>{
      'type': 'profile',
      'displayName': profile['displayName'] as String? ?? 'You',
      'username': ?username,
      'bio': ?bio,
      if (avatar is Map<String, dynamic>) 'avatar': avatar,
    };
  }

  Future<void> _announceProfileTo(String peerId, {bool force = false}) async {
    if (peerId == _self()) return;
    if (!force && _announcedTo.contains(peerId)) return;
    if (_settings?.isBlocked(peerId) ?? false) return;
    _announcedTo.add(peerId);
    try {
      final sealed = SealedMessagePayload(
        messageId: _uuid.v4(),
        senderAccountId: _self(),
        senderDeviceId: _device(),
        body: await _mySnapshot(),
      );
      await _sendSealed(peerAccountId: peerId, payload: sealed, control: true);
    } catch (_) {
      _announcedTo.remove(peerId);
    }
  }

  @override
  Future<void> announceProfileToActiveChats() async {
    _meSnapshot = null;
    _announcedTo.clear();
    final self = _self();
    final summaries = await _db.chatSummaries(self);
    for (final s in summaries) {
      final peerId = s.user.id;
      if (peerId == self) continue;
      await _announceProfileTo(peerId, force: true);
    }
  }

  Future<void> _insertLocalSent({
    required String peerAccountId,
    required Message message,
  }) async {
    final self = _self();
    final chatId = await _db.ensureDmChat(peerAccountId, self);
    await _db.insertMessage(
      message.copyWith(status: MessageStatus.sent),
      chatId: chatId,
    );
  }

  @override
  Future<CurrentUser> getCurrentUser() async {
    if (_me != null) return _me!;
    final material = await _vault.loadOrThrow();
    final rows = await _client
        .from('accounts')
        .select('id, username, identity_public_key, profile_ciphertext')
        .eq('id', _self())
        .limit(1);
    final raw = rows.isNotEmpty ? rows.first : <String, dynamic>{};
    final cipher = await ProfileCipher.fromIdentitySeed(material.identitySeed);
    final profile = await cipher.decrypt(raw['profile_ciphertext'] as String?);
    _me = CurrentUser(
      id: raw['id'] as String? ?? _self(),
      name: profile['displayName'] as String? ?? 'You',
      avatarUrl: profile['avatarUrl'] as String? ?? '',
      username: raw['username'] as String?,
      bio: profile['bio'] as String?,
    );
    return _me!;
  }

  @override
  Future<List<ChatSummary>> getChatSummaries() async {
    await ensureRelayStarted();
    return _db.chatSummaries(_self());
  }

  @override
  Stream<List<ChatSummary>> watchChatSummaries() async* {
    await ensureRelayStarted();
    final self = _self();
    yield await _db.chatSummaries(self);
    yield* _db.watchChats().asyncMap((_) => _db.chatSummaries(self));
  }

  @override
  Future<List<Message>> getMessages(String chatId) =>
      _db.messagesForChat(chatId);

  @override
  Stream<List<Message>> watchMessages(String chatId) async* {
    yield await _db.messagesForChat(chatId);
    yield* _db
        .watchMessages(chatId)
        .asyncMap((_) => _db.messagesForChat(chatId));
  }

  @override
  Future<bool> isPeerTyping(String chatId) async {
    final peer = await _peerFromChat(chatId);
    return _typingByPeer[peer] ?? false;
  }

  @override
  Stream<bool> watchPeerTyping(String chatId) async* {
    final peer = await _peerFromChat(chatId);
    yield _typingByPeer[peer] ?? false;
    await for (final event in _typingCtrl.stream) {
      if (event.peerAccountId == peer) yield event.isTyping;
    }
  }

  @override
  void sendTyping({required String chatId, required bool isTyping}) {
    unawaited(() async {
      final peer = await _peerFromChat(chatId);
      try {
        await _client.rpc<void>(
          'send_typing',
          params: <String, dynamic>{'p_peer': peer, 'p_is_typing': isTyping},
        );
      } catch (_) {}
    }());
  }

  @override
  Future<User> fetchPeerWithPresence(String peerAccountId) async {
    final base =
        await _db.peer(peerAccountId) ??
        User(
          id: peerAccountId,
          name: 'Unknown',
          avatarUrl: '',
          isOnline: false,
        );
    final presence = await _fetchPresence(peerAccountId);
    if (presence == null) return base;
    return base.copyWith(isOnline: presence.$1, lastSeenAt: presence.$2);
  }

  @override
  Stream<User> watchPeerPresence(String peerAccountId) {
    late StreamController<User> ctrl;
    Timer? timer;
    StreamSubscription<String>? liveSub;
    Future<void> push() async {
      try {
        final u = await fetchPeerWithPresence(peerAccountId);
        if (!ctrl.isClosed) ctrl.add(u);
      } catch (_) {}
    }

    ctrl = StreamController<User>(
      onListen: () {
        unawaited(push());
        timer = Timer.periodic(const Duration(seconds: 20), (_) => push());
        liveSub = _presenceEventCtrl.stream
            .where((id) => id == peerAccountId)
            .listen((_) => push());
      },
      onCancel: () async {
        timer?.cancel();
        await liveSub?.cancel();
      },
    );
    return ctrl.stream;
  }

  @override
  Future<Uint8List?> loadPeerAvatar(User peer) async {
    final ref = peer.avatarBlob;
    if (ref == null) return null;
    final cached = _peerAvatarBytes[ref.objectKey];
    if (cached != null) return cached;
    try {
      final bytes = await _blobStore.download(ref);
      _peerAvatarBytes[ref.objectKey] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<(bool, DateTime?)?> _fetchPresence(String accountId) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'get_presence',
        params: <String, dynamic>{'p_account': accountId},
      );
      if (rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      final lastRaw = row['last_seen_at'] as String?;
      return (
        row['is_online'] as bool? ?? false,
        lastRaw != null ? DateTime.parse(lastRaw).toUtc() : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Message> sendText({
    required String chatId,
    required String text,
    ReplyPreview? replyTo,
  }) async {
    final peerId = await _peerFromChat(chatId);
    if (_settings?.isBlocked(peerId) ?? false) {
      throw StateError('Cannot message a blocked user');
    }
    unawaited(_announceProfileTo(peerId));
    final self = _self();
    final messageId = _uuid.v4();
    final noForward = await _noForward();
    final sealed = SealedMessagePayload(
      messageId: messageId,
      senderAccountId: self,
      senderDeviceId: _device(),
      body: <String, dynamic>{
        'type': 'text',
        'text': text,
        'replyToId': ?replyTo?.messageId,
        if (noForward) 'noForward': true,
      },
    );
    try {
      await _sendSealed(peerAccountId: peerId, payload: sealed);
    } catch (e) {
      final noBundle = e.toString().contains('No libsignal bundle');
      throw SendMessageException(
        noBundle
            ? "This person hasn't set up secure messaging on their device yet, "
                  'so your message can’t be delivered.'
            : 'Couldn’t send your message. Check your connection and try again.',
        recoverable: !noBundle,
      );
    }
    final msg = Message(
      id: messageId,
      senderId: self,
      type: MessageType.text,
      timestamp: DateTime.now().toUtc(),
      text: text,
      status: MessageStatus.sent,
      noForward: noForward,
    );
    await _insertLocalSent(peerAccountId: peerId, message: msg);
    return msg;
  }

  Future<bool> _noForward() async =>
      !((await _settings?.load())?.allowForwarding ?? true);

  Future<String> _peerFromChat(String chatId) async {
    final self = _self();
    final parts = chatId.split('|');
    if (parts.length == 3 && parts[0] == 'dm') {
      return parts[1] == self ? parts[2] : parts[1];
    }
    throw ArgumentError('Invalid chat id');
  }

  @override
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    await _db.deleteMessage(chatId, messageId);
    await _sendControl(chatId, <String, dynamic>{
      'type': 'delete',
      'messageId': messageId,
    });
  }

  @override
  Future<void> editText({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    await _db.updateMessageText(chatId, messageId, newText);
    await _sendControl(chatId, <String, dynamic>{
      'type': 'edit',
      'messageId': messageId,
      'text': newText,
    });
  }

  Future<void> _sendControl(String chatId, Map<String, dynamic> body) async {
    try {
      final peerId = await _peerFromChat(chatId);
      if (peerId == _self()) return;
      if (_settings?.isBlocked(peerId) ?? false) return;
      final sealed = SealedMessagePayload(
        messageId: _uuid.v4(),
        senderAccountId: _self(),
        senderDeviceId: _device(),
        body: body,
      );
      await _sendSealed(peerAccountId: peerId, payload: sealed, control: true);
    } catch (_) {}
  }

  @override
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    final self = _self();
    final peerId = await _peerFromChat(chatId);
    if (_settings?.isBlocked(peerId) ?? false) return;
    await _db.toggleReaction(
      chatId: chatId,
      messageId: messageId,
      userId: self,
      emoji: emoji,
    );
    final sealed = SealedMessagePayload(
      messageId: _uuid.v4(),
      senderAccountId: self,
      senderDeviceId: _device(),
      body: <String, dynamic>{
        'type': 'reaction',
        'messageId': messageId,
        'emoji': emoji,
      },
    );
    await _sendSealed(peerAccountId: peerId, payload: sealed, control: true);
  }

  @override
  Future<Message> forwardMessage({
    required String sourceChatId,
    required String messageId,
    required String destinationChatId,
  }) async {
    final src = await _db.messagesForChat(sourceChatId);
    final m = src.firstWhere((x) => x.id == messageId);
    final att = m.attachment;
    if (m.type == MessageType.location &&
        att?.lat != null &&
        att?.lng != null) {
      return sendLocation(
        chatId: destinationChatId,
        lat: att!.lat!,
        lng: att.lng!,
        caption: m.text,
      );
    }
    if (att != null && att.hasBlob) {
      return _forwardMedia(destinationChatId, m);
    }
    return sendText(chatId: destinationChatId, text: m.text ?? '');
  }

  Future<Message> _forwardMedia(String chatId, Message src) async {
    final peerId = await _peerFromChat(chatId);
    if (_settings?.isBlocked(peerId) ?? false) {
      throw const SendMessageException(
        'Cannot message a blocked user',
        recoverable: false,
      );
    }
    unawaited(_announceProfileTo(peerId));
    final self = _self();
    final messageId = _uuid.v4();
    final noForward = await _noForward();
    final att = src.attachment!;
    final sealed = SealedMessagePayload(
      messageId: messageId,
      senderAccountId: self,
      senderDeviceId: _device(),
      body: <String, dynamic>{
        'type': src.type.name,
        'caption': ?src.text,
        if (noForward) 'noForward': true,
        'attachment': att.toJson(),
      },
    );
    try {
      await _sendSealed(peerAccountId: peerId, payload: sealed);
    } catch (e) {
      final noBundle = e.toString().contains('No libsignal bundle');
      throw SendMessageException(
        noBundle
            ? 'This person hasn’t set up secure messaging yet.'
            : 'Couldn’t forward the media. Check your connection and try again.',
        recoverable: !noBundle,
      );
    }
    final msg = Message(
      id: messageId,
      senderId: self,
      type: src.type,
      timestamp: DateTime.now().toUtc(),
      text: src.text,
      attachment: att,
      status: MessageStatus.sent,
      noForward: noForward,
    );
    await _insertLocalSent(peerAccountId: peerId, message: msg);
    return msg;
  }

  @override
  Future<void> setMuted({required String chatId, required bool muted}) =>
      _db.setMuted(chatId, muted);

  @override
  Future<bool> setPinned({required String chatId, required bool pinned}) async {
    final summaries = await getChatSummaries();
    final pinnedCount = summaries.where((s) => s.isPinned).length;
    if (pinned && pinnedCount >= MessengerRepository.pinnedChatLimit) {
      return false;
    }
    await _db.setPinned(chatId, pinned);
    return true;
  }

  @override
  Future<void> markChatRead({required String chatId}) async {
    await _db.setUnread(chatId, 0);
    if ((await _settings?.load())?.sendReadReceipts ?? true) {
      await _sendControl(chatId, <String, dynamic>{'type': 'read'});
    }
  }

  @override
  Future<void> deleteChat({
    required String chatId,
    bool forEveryone = false,
  }) async {
    await _db.deleteChat(chatId);
    if (forEveryone) {
      await _sendControl(chatId, <String, dynamic>{'type': 'deleteChat'});
    }
  }

  @override
  Future<void> setPinnedMessage({
    required String chatId,
    required String? messageId,
  }) async {
    await _db.setPinnedMessageId(chatId, messageId);
    await _sendControl(chatId, <String, dynamic>{
      'type': 'pin',
      'messageId': ?messageId,
    });
  }

  @override
  Future<void> setDraft({required String chatId, required String text}) =>
      _db.setDraft(chatId, text);

  @override
  Future<String> getDraft(String chatId) => _db.draft(chatId);

  @override
  Future<List<User>> getContactableUsers() => _db.allPeers();

  @override
  Future<ChatSummary> openSavedMessages() async {
    final self = _self();
    final chatId = await _db.ensureDmChat(self, self);
    final me = await getCurrentUser();
    return ChatSummary(
      id: chatId,
      user: User(
        id: self,
        name: me.name,
        avatarUrl: me.avatarUrl,
        isOnline: true,
      ),
      lastMessage: '',
      timestamp: DateTime.now(),
      unreadCount: 0,
    );
  }

  @override
  Future<List<MessageHit>> searchMessages(String query) async {
    final self = _self();
    return _db.searchMessages(self, query);
  }

  @override
  Future<List<User>> searchContacts(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return <User>[];
    final all = await _db.allPeers();
    return all
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) ||
              (u.username?.toLowerCase().contains(q) ?? false),
        )
        .toList(growable: false);
  }

  @override
  Future<ChatSummary> openChatWith(User user) async {
    final self = _self();
    await _db.upsertPeer(user);
    if (user.id != self) unawaited(_announceProfileTo(user.id));
    final chatId = await _db.ensureDmChat(user.id, self);
    final summaries = await _db.chatSummaries(self);
    return summaries.firstWhere(
      (s) => s.id == chatId,
      orElse: () => ChatSummary(
        id: chatId,
        user: user,
        lastMessage: '',
        timestamp: DateTime.now(),
        unreadCount: 0,
      ),
    );
  }

  @override
  Future<ChatSummary> openChatByUsername(String username) async {
    final rows = await _client
        .from('accounts')
        .select('id, username, identity_public_key, profile_ciphertext')
        .eq('username', username)
        .limit(1);
    if (rows.isEmpty) throw StateError('User not found');
    final raw = rows.first;
    final user = User(
      id: raw['id'] as String,
      name: raw['username'] as String? ?? username,
      username: raw['username'] as String?,
      avatarUrl: '',
      isOnline: false,
    );
    return openChatWith(user);
  }
}

SignedPreKeyFetcher supabaseSignedPreKeyFetcher(SupabaseClient client) {
  return (String peerAccountId) async {
    final rows = await client.rpc<List<dynamic>>(
      'claim_prekey_bundle',
      params: <String, dynamic>{'p_account': peerAccountId},
    );
    if (rows.isEmpty) throw StateError('preKeyBundle');
    final row = rows.first as Map<String, dynamic>;
    final signed = row['signed_public_key'] as String?;
    if (signed == null) throw StateError('preKeyBundle');
    return _base64ToBytes(signed, expectedLen: 32);
  };
}

class TypingPing {
  const TypingPing({required this.peerAccountId, required this.isTyping});

  final String peerAccountId;
  final bool isTyping;
}

class IncomingMessage {
  const IncomingMessage({
    required this.chatId,
    required this.senderName,
    required this.preview,
  });

  final String chatId;
  final String senderName;
  final String preview;
}

String _toBase64Url(String standardB64) =>
    encodeBase64Url(decodePgBase64(standardB64));

Uint8List _base64ToBytes(String standardB64, {int? expectedLen}) {
  final bytes = decodePgBase64(standardB64);
  if (expectedLen != null && bytes.length != expectedLen) {
    throw FormatException('Expected $expectedLen bytes, got ${bytes.length}');
  }
  return bytes;
}
