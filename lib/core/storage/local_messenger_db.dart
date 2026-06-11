import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../crypto/encrypted_blob_store.dart';
import '../../features/messages/domain/entities/attachment.dart';
import '../../features/messages/domain/entities/chat_list_kind.dart';
import '../../features/messages/domain/entities/chat_summary.dart';
import '../../features/messages/domain/entities/message.dart';
import '../../features/messages/domain/entities/message_hit.dart';
import '../../features/messages/domain/entities/message_status.dart';
import '../../features/messages/domain/entities/message_type.dart';
import '../../features/messages/domain/entities/user.dart';

String _previewForMessage(Message m) {
  final caption = (m.text ?? '').trim();
  switch (m.type) {
    case MessageType.text:
      return caption;
    case MessageType.image:
      return caption.isEmpty ? 'photo' : 'photo · $caption';
    case MessageType.gif:
      return caption.isEmpty ? 'gif' : 'gif · $caption';
    case MessageType.sticker:
      return 'sticker';
    case MessageType.video:
      return caption.isEmpty ? 'video' : 'video · $caption';
    case MessageType.voice:
      return 'voice note';
    case MessageType.audio:
      return caption.isNotEmpty ? caption : (m.attachment?.fileName ?? 'audio');
    case MessageType.file:
      return m.attachment?.fileName ?? 'file';
    case MessageType.location:
      return 'location';
  }
}

class LocalMessengerDb {
  LocalMessengerDb._(this._accountId);

  final String _accountId;

  static final Map<String, LocalMessengerDb> _instances =
      <String, LocalMessengerDb>{};

  static LocalMessengerDb forAccount(String accountId) =>
      _instances[accountId] ??= LocalMessengerDb._(accountId);

  static final LocalMessengerDb instance = forAccount('');

  Database? _db;
  final _chatCtrl = StreamController<void>.broadcast();
  final Map<String, StreamController<void>> _messageCtrls =
      <String, StreamController<void>>{};

  static String _fileSafe(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final suffix = _accountId.isEmpty ? '' : '_${_fileSafe(_accountId)}';
    final path = p.join(dir.path, 'yapp_messenger$suffix.db');
    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE peers (
            account_id TEXT PRIMARY KEY,
            username TEXT,
            display_name TEXT NOT NULL DEFAULT '',
            identity_public_key TEXT,
            avatar_ref TEXT,
            bio TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE chats (
            id TEXT PRIMARY KEY,
            peer_account_id TEXT NOT NULL,
            last_message_at INTEGER NOT NULL,
            unread INTEGER NOT NULL DEFAULT 0,
            draft TEXT NOT NULL DEFAULT '',
            pinned INTEGER NOT NULL DEFAULT 0,
            muted INTEGER NOT NULL DEFAULT 0,
            pinned_message_id TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            type TEXT NOT NULL,
            text TEXT,
            payload_json TEXT,
            timestamp INTEGER NOT NULL,
            status TEXT NOT NULL,
            edited_at INTEGER,
            forwarded_from TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE crypto_sessions (
            peer_account_id TEXT PRIMARY KEY,
            shared_key_hex TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE signal_sessions (
            peer_account_id TEXT PRIMARY KEY,
            state_b64 TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX messages_chat_ts ON messages(chat_id, timestamp)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS signal_sessions (
              peer_account_id TEXT PRIMARY KEY,
              state_b64 TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE peers ADD COLUMN avatar_ref TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE peers ADD COLUMN bio TEXT');
        }
      },
    );
    return _db!;
  }

  Stream<void> watchChats() => _chatCtrl.stream;

  Stream<void> watchMessages(String chatId) {
    return (_messageCtrls[chatId] ??= StreamController<void>.broadcast())
        .stream;
  }

  void _notifyChat() => _chatCtrl.add(null);

  void _notifyMessages(String chatId) => _messageCtrls[chatId]?.add(null);

  static String dmChatId(String a, String b) {
    final ids = [a, b]..sort();
    return 'dm|${ids[0]}|${ids[1]}';
  }

  Future<void> upsertPeer(User user) async {
    final db = await _open();
    final existing = await db.query(
      'peers',
      where: 'account_id = ?',
      whereArgs: [user.id],
    );
    if (existing.isEmpty) {
      await db.insert('peers', <String, Object?>{
        'account_id': user.id,
        'username': user.username,
        'display_name': user.name,
        'identity_public_key': null,
        'avatar_ref': _encodeAvatar(user.avatarBlob),
      });
    } else {
      final row = existing.first;
      final values = <String, Object?>{};
      final knownUser = (row['username'] as String?) ?? '';
      if (knownUser.isEmpty && (user.username?.isNotEmpty ?? false)) {
        values['username'] = user.username;
      }
      if (values.isNotEmpty) {
        await db.update(
          'peers',
          values,
          where: 'account_id = ?',
          whereArgs: [user.id],
        );
      }
    }
    _notifyChat();
  }

  Future<void> applyPeerProfile({
    required String accountId,
    required String displayName,
    String? username,
    EncryptedBlobRef? avatar,
    String? bio,
  }) async {
    final db = await _open();
    await db.insert('peers', <String, Object?>{
      'account_id': accountId,
      'username': username,
      'display_name': displayName,
      'identity_public_key': null,
      'avatar_ref': _encodeAvatar(avatar),
      'bio': bio,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _notifyChat();
  }

  static String? _encodeAvatar(EncryptedBlobRef? ref) =>
      ref == null ? null : jsonEncode(ref.toJson());

  static EncryptedBlobRef? _decodeAvatar(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      return EncryptedBlobRef.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<User?> peer(String accountId) async {
    final db = await _open();
    final rows = await db.query(
      'peers',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    if (rows.isEmpty) return null;
    return _rowToUser(rows.first);
  }

  Future<List<User>> allPeers() async {
    final db = await _open();
    final rows = await db.query('peers', orderBy: 'display_name ASC');
    return rows.map(_rowToUser).toList(growable: false);
  }

  User _rowToUser(Map<String, Object?> r) => User(
    id: r['account_id']! as String,
    name: r['display_name']! as String,
    username: r['username'] as String?,
    avatarUrl: '',
    isOnline: false,
    avatarBlob: _decodeAvatar(r['avatar_ref']),
    bio: r['bio'] as String?,
  );

  Future<String> ensureDmChat(String peerAccountId, String selfId) async {
    final chatId = dmChatId(selfId, peerAccountId);
    final db = await _open();
    await db.insert('chats', <String, Object?>{
      'id': chatId,
      'peer_account_id': peerAccountId,
      'last_message_at': DateTime.now().millisecondsSinceEpoch,
      'unread': 0,
      'draft': '',
      'pinned': 0,
      'muted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    _notifyChat();
    return chatId;
  }

  Future<List<ChatSummary>> chatSummaries(String selfId) async {
    final db = await _open();
    final rows = await db.query(
      'chats',
      orderBy: 'pinned DESC, last_message_at DESC',
    );
    final out = <ChatSummary>[];
    for (final r in rows) {
      final chatId = r['id']! as String;
      final peerId = r['peer_account_id']! as String;
      final isSelf = peerId == selfId;
      final peerUser = isSelf
          ? User(id: peerId, name: 'you', avatarUrl: '', isOnline: false)
          : (await peer(peerId) ??
                User(
                  id: peerId,
                  name: 'Unknown',
                  avatarUrl: '',
                  isOnline: false,
                ));
      final last = await _lastMessage(chatId);
      out.add(
        ChatSummary(
          id: chatId,
          user: peerUser,
          kind: isSelf ? ChatListKind.saved : ChatListKind.dm,
          lastMessage: last == null ? '' : _previewForMessage(last),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            r['last_message_at']! as int,
          ),
          unreadCount: r['unread']! as int,
          isPinned: (r['pinned']! as int) == 1,
          isMuted: (r['muted']! as int) == 1,
          pinnedMessageId: r['pinned_message_id'] as String?,
          draft: r['draft']! as String,
        ),
      );
    }
    return out;
  }

  Future<Map<String, dynamic>?> _lastMessageRow(String chatId) async {
    final db = await _open();
    final rows = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Message?> _lastMessage(String chatId) async {
    final row = await _lastMessageRow(chatId);
    if (row == null) return null;
    return _rowToMessage(row);
  }

  Future<void> insertMessage(Message msg, {required String chatId}) async {
    final db = await _open();
    await db.insert(
      'messages',
      _messageToRow(msg, chatId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.update(
      'chats',
      <String, Object?>{
        'last_message_at': msg.timestamp.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [chatId],
    );
    _notifyMessages(chatId);
    _notifyChat();
  }

  Future<List<Message>> messagesForChat(String chatId) async {
    final db = await _open();
    final rows = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_rowToMessage).toList(growable: false);
  }

  Future<void> saveSessionKey(String peerId, String sharedKeyHex) async {
    final db = await _open();
    await db.insert('crypto_sessions', <String, Object?>{
      'peer_account_id': peerId,
      'shared_key_hex': sharedKeyHex,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveSignalSession(String peerId, String stateB64) async {
    final db = await _open();
    await db.insert('signal_sessions', <String, Object?>{
      'peer_account_id': peerId,
      'state_b64': stateB64,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> signalSessionState(String peerId) async {
    final db = await _open();
    final rows = await db.query(
      'signal_sessions',
      where: 'peer_account_id = ?',
      whereArgs: [peerId],
    );
    if (rows.isEmpty) return null;
    return rows.first['state_b64'] as String?;
  }

  Future<String?> sessionKeyHex(String peerId) async {
    final db = await _open();
    final rows = await db.query(
      'crypto_sessions',
      where: 'peer_account_id = ?',
      whereArgs: [peerId],
    );
    if (rows.isEmpty) return null;
    return rows.first['shared_key_hex'] as String?;
  }

  Future<void> setUnread(String chatId, int count) async {
    final db = await _open();
    await db.update(
      'chats',
      <String, Object?>{'unread': count},
      where: 'id = ?',
      whereArgs: [chatId],
    );
    _notifyChat();
  }

  Future<void> markOutgoingRead(String chatId, String selfSenderId) async {
    final db = await _open();
    final n = await db.update(
      'messages',
      <String, Object?>{'status': MessageStatus.read.name},
      where: "chat_id = ? AND sender_id = ? AND status IN ('sent','delivered')",
      whereArgs: [chatId, selfSenderId],
    );
    if (n > 0) _notifyMessages(chatId);
  }

  Future<void> setMuted(String chatId, bool muted) async {
    final db = await _open();
    await db.update(
      'chats',
      <String, Object?>{'muted': muted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [chatId],
    );
    _notifyChat();
  }

  Future<void> setPinned(String chatId, bool pinned) async {
    final db = await _open();
    await db.update(
      'chats',
      <String, Object?>{'pinned': pinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [chatId],
    );
    _notifyChat();
  }

  Future<void> setPinnedMessageId(String chatId, String? messageId) async {
    final db = await _open();
    await db.update(
      'chats',
      <String, Object?>{'pinned_message_id': messageId},
      where: 'id = ?',
      whereArgs: [chatId],
    );
    _notifyChat();
  }

  Future<void> deleteChat(String chatId) async {
    final db = await _open();
    await db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
    await db.delete('chats', where: 'id = ?', whereArgs: [chatId]);
    _notifyMessages(chatId);
    _notifyChat();
  }

  Future<List<MessageHit>> searchMessages(String selfId, String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return <MessageHit>[];
    final db = await _open();
    final rows = await db.query(
      'messages',
      where: 'LOWER(text) LIKE ?',
      whereArgs: ['%$q%'],
      orderBy: 'timestamp DESC',
      limit: 80,
    );
    final summaries = await chatSummaries(selfId);
    final byChat = {for (final s in summaries) s.id: s};
    final hits = <MessageHit>[];
    for (final row in rows) {
      final chatId = row['chat_id']! as String;
      final summary = byChat[chatId];
      if (summary == null) continue;
      hits.add(MessageHit(summary: summary, message: _rowToMessage(row)));
    }
    return hits;
  }

  Future<void> setDraft(String chatId, String text) async {
    final db = await _open();
    await db.update(
      'chats',
      <String, Object?>{'draft': text},
      where: 'id = ?',
      whereArgs: [chatId],
    );
    _notifyChat();
  }

  Future<String> draft(String chatId) async {
    final db = await _open();
    final rows = await db.query('chats', where: 'id = ?', whereArgs: [chatId]);
    if (rows.isEmpty) return '';
    return rows.first['draft']! as String;
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    final db = await _open();
    await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    _notifyMessages(chatId);
    _notifyChat();
  }

  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    final db = await _open();
    final rows = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
    if (rows.isEmpty) return;
    final row = rows.first;
    final payload = row['payload_json'] as String?;
    final reactions = _parseReactions(payload);
    final attachment = _parseAttachment(payload);
    final noForward = _parseNoForward(payload);
    final users = reactions.putIfAbsent(emoji, () => <String>[]);
    if (users.contains(userId)) {
      users.remove(userId);
      if (users.isEmpty) reactions.remove(emoji);
    } else {
      users.add(userId);
    }
    await db.update(
      'messages',
      <String, Object?>{
        'payload_json': _encodePayload(
          reactions,
          attachment,
          noForward: noForward,
        ),
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
    _notifyMessages(chatId);
  }

  Map<String, List<String>> _parseReactions(String? raw) {
    if (raw == null || raw.isEmpty) return <String, List<String>>{};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final r =
          map['reactions'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return r.map(
        (k, v) =>
            MapEntry(k, (v as List<dynamic>).map((e) => e.toString()).toList()),
      );
    } catch (_) {
      return <String, List<String>>{};
    }
  }

  Future<void> updateMessageText(
    String chatId,
    String messageId,
    String text,
  ) async {
    final db = await _open();
    await db.update(
      'messages',
      <String, Object?>{
        'text': text,
        'edited_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
    _notifyMessages(chatId);
  }

  Map<String, Object?> _messageToRow(Message m, String chatId) =>
      <String, Object?>{
        'id': m.id,
        'chat_id': chatId,
        'sender_id': m.senderId,
        'type': m.type.name,
        'text': m.text,
        'payload_json': _encodePayload(
          m.reactions,
          m.attachment,
          noForward: m.noForward,
        ),
        'timestamp': m.timestamp.millisecondsSinceEpoch,
        'status': m.status.name,
        'edited_at': m.editedAt?.millisecondsSinceEpoch,
        'forwarded_from': m.forwardedFromName,
      };

  Message _rowToMessage(Map<String, Object?> r) {
    final payload = r['payload_json'] as String?;
    return Message(
      id: r['id']! as String,
      senderId: r['sender_id']! as String,
      type: _typeFromName(r['type'] as String?),
      timestamp: DateTime.fromMillisecondsSinceEpoch(r['timestamp']! as int),
      text: r['text'] as String?,
      attachment: _parseAttachment(payload),
      status: MessageStatus.values.byName(r['status']! as String),
      editedAt: r['edited_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(r['edited_at']! as int)
          : null,
      forwardedFromName: r['forwarded_from'] as String?,
      reactions: _parseReactions(payload),
      noForward: _parseNoForward(payload),
    );
  }

  MessageType _typeFromName(String? name) {
    if (name == null) return MessageType.text;
    for (final t in MessageType.values) {
      if (t.name == name) return t;
    }
    return MessageType.text;
  }

  String? _encodePayload(
    Map<String, List<String>> reactions,
    Attachment? att, {
    bool noForward = false,
  }) {
    final m = <String, dynamic>{};
    if (reactions.isNotEmpty) m['reactions'] = reactions;
    if (att != null) m['attachment'] = att.toJson();
    if (noForward) m['noForward'] = true;
    return m.isEmpty ? null : jsonEncode(m);
  }

  bool _parseNoForward(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    try {
      return (jsonDecode(raw) as Map<String, dynamic>)['noForward'] == true;
    } catch (_) {
      return false;
    }
  }

  Attachment? _parseAttachment(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final a = map['attachment'] as Map<String, dynamic>?;
      return a == null ? null : Attachment.fromJson(a);
    } catch (_) {
      return null;
    }
  }
}
