import 'dart:async';

import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/chat_list_kind.dart';
import '../../domain/entities/chat_summary.dart';
import '../../domain/entities/current_user.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_hit.dart';
import '../../domain/entities/message_type.dart';
import '../../domain/entities/reply_preview.dart';
import '../../domain/entities/user.dart';

class MessengerFakeLocalDatasource {
  MessengerFakeLocalDatasource({SettingsRepository? settingsRepository});

  static const String currentUserId = 'user_me';
  static const String chatJacobId = 'chat_jacob';
  static const String savedMessagesChatId = 'chat_saved_me';

  static final CurrentUser _currentUser = CurrentUser(
    id: currentUserId,
    name: 'Alex Rivera',
    avatarUrl: _avatar(33),
    username: 'alexrivera',
    bio: 'Product · NYC · usually in DMs',
    phoneDisplay: '+1 212 555 0198',
  );

  static final User _meAsUser = User(
    id: currentUserId,
    name: 'Saved messages',
    avatarUrl: _currentUser.avatarUrl,
    isOnline: true,
    lastSeenAt: DateTime.now(),
  );

  static String _avatar(int seed) => 'https://i.pravatar.cc/300?img=$seed';

  static final Map<String, User> _users = {
    'user_jacob': User(
      id: 'user_jacob',
      name: 'Jacob Jones',
      avatarUrl: _avatar(12),
      isOnline: false,
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 22)),
    ),
    'user_ronald': User(
      id: 'user_ronald',
      name: 'Ronald Richards',
      avatarUrl: _avatar(15),
      isOnline: true,
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    'user_leslie': User(
      id: 'user_leslie',
      name: 'Leslie Alexander',
      avatarUrl: _avatar(5),
      isOnline: false,
      lastSeenAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    'user_jane': User(
      id: 'user_jane',
      name: 'Jane Cooper',
      avatarUrl: _avatar(9),
      isOnline: false,
      lastSeenAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
    'user_robert': User(
      id: 'user_robert',
      name: 'Robert Fox',
      avatarUrl: _avatar(52),
      isOnline: false,
      lastSeenAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    'user_cody': User(
      id: 'user_cody',
      name: 'Cody Fisher',
      avatarUrl: _avatar(60),
      isOnline: false,
      lastSeenAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
  };

  late final List<ChatSummary> _summaries = [
    ChatSummary(
      id: savedMessagesChatId,
      kind: ChatListKind.saved,
      user: _meAsUser,
      lastMessage: 'Reading list · 3 links',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      unreadCount: 0,
      isPinned: true,
    ),
    ChatSummary(
      id: chatJacobId,
      user: _users['user_jacob']!,
      lastMessage: 'ok! c u later. =D',
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      unreadCount: 0,
    ),
    ChatSummary(
      id: 'chat_ronald',
      user: _users['user_ronald']!,
      lastMessage: 'Sounds good — I will send the file in a bit.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      unreadCount: 1,
    ),
    ChatSummary(
      id: 'chat_leslie',
      user: _users['user_leslie']!,
      lastMessage: 'Can we reschedule to Thursday?',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      unreadCount: 0,
    ),
    ChatSummary(
      id: 'chat_jane',
      user: _users['user_jane']!,
      lastMessage: 'Thanks! Talk soon.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
    ),
    ChatSummary(
      id: 'chat_robert',
      user: _users['user_robert']!,
      lastMessage: 'See you at the venue.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 0,
    ),
    ChatSummary(
      id: 'chat_cody',
      user: _users['user_cody']!,
      lastMessage: '👍',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      unreadCount: 0,
    ),
  ];

  late final Map<String, List<Message>> _messagesByChat = {
    chatJacobId: [
      Message(
        id: 'm1',
        senderId: 'user_jacob',
        type: MessageType.text,
        timestamp: DateTime(2026, 4, 16, 12, 45),
        text: 'voice note removed — text-only for now.',
      ),
      Message(
        id: 'm2',
        senderId: currentUserId,
        type: MessageType.text,
        timestamp: DateTime(2026, 4, 16, 13, 6),
        text:
            'No, meet @ my house at 5:45. Then we can take the bus 2 the cinema.',
      ),
      Message(
        id: 'm3',
        senderId: 'user_jacob',
        type: MessageType.text,
        timestamp: DateTime(2026, 4, 16, 13, 8),
        text: 'ok! c u later. =D',
      ),
      Message(
        id: 'm4',
        senderId: currentUserId,
        type: MessageType.text,
        timestamp: DateTime(2026, 4, 16, 13, 9),
        text: '👍',
      ),
    ],
    'chat_ronald': [
      Message(
        id: 'r1',
        senderId: 'user_ronald',
        type: MessageType.text,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        text: 'Hey — did you get a chance to review the deck?',
      ),
    ],
    savedMessagesChatId: [
      Message(
        id: 'sv1',
        senderId: currentUserId,
        type: MessageType.text,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        text:
            'Welcome to Saved Messages — your personal cloud.\n\n'
            '• Forward any message here to keep it.\n'
            '• Paste links, snippets and notes.\n'
            '• Only you can see these.',
      ),
      Message(
        id: 'sv2',
        senderId: currentUserId,
        type: MessageType.text,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        text:
            'Reading list:\n'
            'https://flutter.dev\n'
            'https://dart.dev/guides/language\n'
            'https://docs.flutter.dev/ui',
      ),
      Message(
        id: 'sv3',
        senderId: currentUserId,
        type: MessageType.text,
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        text:
            '```dart\n'
            '// Quick snippet\n'
            'void greet(String name) {\n'
            '  print(\'hi \$name\');\n'
            '}\n'
            '```',
      ),
    ],
  };

  final Map<String, StreamController<List<Message>>> _streams = {};
  final StreamController<List<ChatSummary>> _summaryStream =
      StreamController<List<ChatSummary>>.broadcast();
  int _idSeq = 0;

  Future<CurrentUser> fetchCurrentUser() async => _currentUser;

  Future<List<ChatSummary>> fetchChatSummaries() async => _sortedSummaries();

  List<ChatSummary> _sortedSummaries() {
    final copy = List<ChatSummary>.from(_summaries);
    copy.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.timestamp.compareTo(a.timestamp);
    });
    return copy;
  }

  Stream<List<ChatSummary>> watchChatSummaries() {
    Future<void>.microtask(() {
      if (!_summaryStream.isClosed) {
        _summaryStream.add(_sortedSummaries());
      }
    });
    return _summaryStream.stream;
  }

  void _emitSummaries() {
    if (_summaryStream.isClosed) return;
    _summaryStream.add(_sortedSummaries());
  }

  Future<List<User>> fetchContactableUsers() async {
    return _users.values.toList(growable: false);
  }

  User savedMessagesPeer() => _meAsUser;

  ChatSummary openSavedMessages() {
    return _summaries.firstWhere((s) => s.id == savedMessagesChatId);
  }

  List<User> searchContacts(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <User>[];
    for (final u in _users.values) {
      if (u.name.toLowerCase().contains(q)) {
        out.add(u);
      }
    }
    return out;
  }

  List<MessageHit> searchMessages(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <MessageHit>[];
    for (final summary in _summaries) {
      final list = _messagesByChat[summary.id] ?? const <Message>[];
      for (final m in list) {
        final body = (m.text ?? '').toLowerCase();
        if (body.isEmpty) continue;
        if (body.contains(q)) {
          hits.add(MessageHit(summary: summary, message: m));
        }
      }
    }
    hits.sort((a, b) => b.message.timestamp.compareTo(a.message.timestamp));
    return hits;
  }

  Future<ChatSummary> openChatWith(User user) async {
    final existing = _summaries.firstWhere(
      (s) => s.user.id == user.id,
      orElse: () => _createChatFor(user),
    );
    return existing;
  }

  Future<ChatSummary> openChatByUsername(String username) async {
    final user = _users.values.firstWhere(
      (u) => u.username == username,
      orElse: () => User(
        id: 'user_$username',
        name: username,
        username: username,
        avatarUrl: '',
        isOnline: false,
      ),
    );
    return openChatWith(user);
  }

  ChatSummary _createChatFor(User user) {
    final id = 'chat_${user.id.replaceFirst('user_', '')}';
    final summary = ChatSummary(
      id: id,
      user: user,
      lastMessage: '',
      timestamp: DateTime.now(),
      unreadCount: 0,
    );
    _summaries.add(summary);
    _messagesByChat[id] = [];
    _emitSummaries();
    return summary;
  }

  Future<List<Message>> fetchMessages(String chatId) async {
    final list = _messagesByChat[chatId];
    if (list == null) return [];
    return List<Message>.from(list);
  }

  Future<bool> fetchPeerTyping(String chatId) async => false;

  Stream<List<Message>> watchMessages(String chatId) {
    final controller = _streams.putIfAbsent(
      chatId,
      () => StreamController<List<Message>>.broadcast(
        onListen: () {
          final list = _messagesByChat[chatId] ?? [];
          _streams[chatId]?.add(List<Message>.from(list));
        },
      ),
    );
    return controller.stream;
  }

  String _nextId() {
    _idSeq += 1;
    return 'local_${DateTime.now().microsecondsSinceEpoch}_$_idSeq';
  }

  Message appendOutgoing(String chatId, Message template) {
    final list = _messagesByChat.putIfAbsent(chatId, () => []);
    final msg = template.copyWith(id: template.id.isEmpty ? _nextId() : null);
    list.add(msg);
    _emit(chatId);
    final sIdx = _summaries.indexWhere((s) => s.id == chatId);
    if (sIdx != -1 && _summaries[sIdx].draft.isNotEmpty) {
      _summaries[sIdx] = _summaries[sIdx].copyWith(draft: '');
    }
    _updateSummaryPreview(chatId, msg);
    _maybeAutoReply(chatId);
    return msg;
  }

  void deleteMessage(String chatId, String messageId) {
    final list = _messagesByChat[chatId];
    if (list == null) return;
    list.removeWhere((m) => m.id == messageId);
    final sIdx = _summaries.indexWhere((s) => s.id == chatId);
    if (sIdx != -1 && _summaries[sIdx].pinnedMessageId == messageId) {
      _summaries[sIdx] = _summaries[sIdx].copyWith(clearPinnedMessage: true);
      _emitSummaries();
    }
    _emit(chatId);
  }

  void editText(String chatId, String messageId, String newText) {
    final list = _messagesByChat[chatId];
    if (list == null) return;
    final i = list.indexWhere((m) => m.id == messageId);
    if (i == -1) return;
    final old = list[i];
    if (old.type != MessageType.text) return;
    list[i] = old.copyWith(text: newText, editedAt: DateTime.now());
    _emit(chatId);
    if (i == list.length - 1) _updateSummaryPreview(chatId, list[i]);
  }

  void toggleReaction(String chatId, String messageId, String emoji) {
    final list = _messagesByChat[chatId];
    if (list == null) return;
    final i = list.indexWhere((m) => m.id == messageId);
    if (i == -1) return;
    final old = list[i];
    final reactions = <String, List<String>>{
      for (final e in old.reactions.entries) e.key: List<String>.from(e.value),
    };
    final users = reactions.putIfAbsent(emoji, () => <String>[]);
    if (users.contains(currentUserId)) {
      users.remove(currentUserId);
      if (users.isEmpty) reactions.remove(emoji);
    } else {
      users.add(currentUserId);
    }
    list[i] = old.copyWith(reactions: reactions);
    _emit(chatId);
  }

  Message forwardMessage({
    required String sourceChatId,
    required String messageId,
    required String destinationChatId,
  }) {
    final src = _messagesByChat[sourceChatId];
    if (src == null) {
      throw StateError('Source chat not found');
    }
    final source = src.firstWhere((m) => m.id == messageId);
    final forwarded = Message(
      id: _nextId(),
      senderId: currentUserId,
      type: source.type,
      timestamp: DateTime.now(),
      text: source.text,
      forwardedFromName: source.forwardedFromName ?? nameFor(source.senderId),
    );
    final dest = _messagesByChat.putIfAbsent(destinationChatId, () => []);
    dest.add(forwarded);
    _emit(destinationChatId);
    _updateSummaryPreview(destinationChatId, forwarded);
    return forwarded;
  }

  void setPinnedMessage(String chatId, String? messageId) {
    final idx = _summaries.indexWhere((s) => s.id == chatId);
    if (idx == -1) return;
    _summaries[idx] = _summaries[idx].copyWith(
      pinnedMessageId: messageId,
      clearPinnedMessage: messageId == null,
    );
    _emitSummaries();
  }

  void setDraft(String chatId, String text) {
    final idx = _summaries.indexWhere((s) => s.id == chatId);
    if (idx == -1) return;
    if (_summaries[idx].draft == text) return;
    _summaries[idx] = _summaries[idx].copyWith(draft: text);
    _emitSummaries();
  }

  String getDraft(String chatId) {
    final idx = _summaries.indexWhere((s) => s.id == chatId);
    if (idx == -1) return '';
    return _summaries[idx].draft;
  }

  Message? findMessage(String chatId, String messageId) {
    final list = _messagesByChat[chatId];
    if (list == null) return null;
    for (final m in list) {
      if (m.id == messageId) return m;
    }
    return null;
  }

  void setMuted(String chatId, bool muted) {
    final idx = _summaries.indexWhere((s) => s.id == chatId);
    if (idx == -1) return;
    _summaries[idx] = _summaries[idx].copyWith(isMuted: muted);
    _emitSummaries();
  }

  bool setPinned(String chatId, bool pinned, {required int limit}) {
    final idx = _summaries.indexWhere((s) => s.id == chatId);
    if (idx == -1) return false;
    if (pinned && !_summaries[idx].isPinned) {
      final alreadyPinned = _summaries
          .where((s) => s.isPinned && s.id != savedMessagesChatId)
          .length;
      if (chatId != savedMessagesChatId && alreadyPinned >= limit) {
        return false;
      }
    }
    _summaries[idx] = _summaries[idx].copyWith(isPinned: pinned);
    _emitSummaries();
    return true;
  }

  void markChatRead(String chatId) {
    final idx = _summaries.indexWhere((s) => s.id == chatId);
    if (idx == -1) return;
    if (_summaries[idx].unreadCount == 0) return;
    _summaries[idx] = _summaries[idx].copyWith(unreadCount: 0);
    _emitSummaries();
  }

  void deleteChat(String chatId) {
    _summaries.removeWhere((s) => s.id == chatId);
    _messagesByChat.remove(chatId);
    _streams.remove(chatId)?.close();
    _emitSummaries();
  }

  void _emit(String chatId) {
    final controller = _streams[chatId];
    if (controller == null || controller.isClosed) return;
    controller.add(List<Message>.from(_messagesByChat[chatId] ?? []));
  }

  void _updateSummaryPreview(String chatId, Message last) {
    final idx = _summaries.indexWhere((s) => s.id == chatId);
    if (idx == -1) return;
    final current = _summaries[idx];
    final preview = _previewFor(last);
    _summaries[idx] = current.copyWith(
      lastMessage: preview,
      timestamp: last.timestamp,
    );
    _emitSummaries();
  }

  String _previewFor(Message m) => m.text ?? '';

  static const _replies = <String>[
    'Got it 👍',
    'Haha yeah',
    'On my way',
    'Okay, talk soon',
    'sounds good',
    '🔥',
    'Let me check',
  ];
  int _replyIdx = 0;

  void _maybeAutoReply(String chatId) {
    if (chatId == savedMessagesChatId) return;
    if (chatId != chatJacobId) return;
    final list = _messagesByChat[chatId];
    if (list == null || list.isEmpty) return;
    final last = list.last;
    if (last.senderId != currentUserId) return;

    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      final reply = _replies[_replyIdx++ % _replies.length];
      list.add(
        Message(
          id: _nextId(),
          senderId: 'user_jacob',
          type: MessageType.text,
          timestamp: DateTime.now(),
          text: reply,
        ),
      );
      _emit(chatId);
      _updateSummaryPreview(chatId, list.last);
    });
  }

  String nameFor(String userId) {
    if (userId == currentUserId) return _currentUser.name;
    return _users[userId]?.name ?? 'Unknown';
  }

  ReplyPreview replyFrom(Message m) {
    final senderName = nameFor(m.senderId);
    return ReplyPreview(
      messageId: m.id,
      senderName: senderName,
      type: m.type,
      text: m.text,
    );
  }
}
