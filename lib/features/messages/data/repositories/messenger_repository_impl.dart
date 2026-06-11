import 'dart:typed_data';

import '../../domain/entities/attachment.dart';
import '../../domain/entities/chat_summary.dart';
import '../../domain/entities/current_user.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_hit.dart';
import '../../domain/entities/message_type.dart';
import '../../domain/entities/reply_preview.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/messenger_repository.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../datasources/messenger_fake_local_datasource.dart';

class MessengerRepositoryImpl implements MessengerRepository {
  MessengerRepositoryImpl({
    MessengerFakeLocalDatasource? datasource,
    SettingsRepository? settingsRepository,
  }) : _datasource =
           datasource ??
           MessengerFakeLocalDatasource(settingsRepository: settingsRepository);

  final MessengerFakeLocalDatasource _datasource;

  MessengerFakeLocalDatasource get datasource => _datasource;

  @override
  Future<CurrentUser> getCurrentUser() => _datasource.fetchCurrentUser();

  @override
  Future<List<ChatSummary>> getChatSummaries() =>
      _datasource.fetchChatSummaries();

  @override
  Stream<List<ChatSummary>> watchChatSummaries() =>
      _datasource.watchChatSummaries();

  @override
  Future<List<Message>> getMessages(String chatId) =>
      _datasource.fetchMessages(chatId);

  @override
  Stream<List<Message>> watchMessages(String chatId) =>
      _datasource.watchMessages(chatId);

  @override
  Future<bool> isPeerTyping(String chatId) =>
      _datasource.fetchPeerTyping(chatId);

  @override
  Stream<bool> watchPeerTyping(String chatId) async* {
    yield await _datasource.fetchPeerTyping(chatId);
  }

  @override
  void sendTyping({required String chatId, required bool isTyping}) {}

  @override
  Future<User> fetchPeerWithPresence(String peerAccountId) async {
    final users = await _datasource.fetchContactableUsers();
    return users.firstWhere(
      (u) => u.id == peerAccountId,
      orElse: () => User(
        id: peerAccountId,
        name: 'Unknown',
        avatarUrl: '',
        isOnline: false,
      ),
    );
  }

  @override
  Stream<User> watchPeerPresence(String peerAccountId) async* {
    yield await fetchPeerWithPresence(peerAccountId);
  }

  @override
  Future<Uint8List?> loadPeerAvatar(User peer) async => null;

  @override
  Future<void> announceProfileToActiveChats() async {}

  @override
  Future<Message> sendText({
    required String chatId,
    required String text,
    ReplyPreview? replyTo,
  }) async {
    final msg = Message(
      id: '',
      senderId: MessengerFakeLocalDatasource.currentUserId,
      type: MessageType.text,
      timestamp: DateTime.now(),
      text: text,
      replyTo: replyTo,
    );
    return _datasource.appendOutgoing(chatId, msg);
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
    final msg = Message(
      id: '',
      senderId: MessengerFakeLocalDatasource.currentUserId,
      type: type,
      timestamp: DateTime.now(),
      text: caption,
      attachment: Attachment(
        fileName: fileName,
        mime: mime,
        size: bytes.length,
      ),
      replyTo: replyTo,
    );
    return _datasource.appendOutgoing(chatId, msg);
  }

  @override
  Future<Message> sendLocation({
    required String chatId,
    required double lat,
    required double lng,
    String? caption,
  }) async {
    final msg = Message(
      id: '',
      senderId: MessengerFakeLocalDatasource.currentUserId,
      type: MessageType.location,
      timestamp: DateTime.now(),
      text: caption,
      attachment: Attachment(lat: lat, lng: lng),
    );
    return _datasource.appendOutgoing(chatId, msg);
  }

  @override
  Future<Uint8List> downloadMedia(Attachment attachment) async => Uint8List(0);

  @override
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    _datasource.deleteMessage(chatId, messageId);
  }

  @override
  Future<void> editText({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    _datasource.editText(chatId, messageId, newText);
  }

  @override
  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) async {
    _datasource.toggleReaction(chatId, messageId, emoji);
  }

  @override
  Future<Message> forwardMessage({
    required String sourceChatId,
    required String messageId,
    required String destinationChatId,
  }) async {
    return _datasource.forwardMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
      destinationChatId: destinationChatId,
    );
  }

  @override
  Future<void> setPinnedMessage({
    required String chatId,
    required String? messageId,
  }) async {
    _datasource.setPinnedMessage(chatId, messageId);
  }

  @override
  Future<void> setDraft({required String chatId, required String text}) async {
    _datasource.setDraft(chatId, text);
  }

  @override
  Future<String> getDraft(String chatId) async => _datasource.getDraft(chatId);

  @override
  Future<void> setMuted({required String chatId, required bool muted}) async {
    _datasource.setMuted(chatId, muted);
  }

  @override
  Future<bool> setPinned({required String chatId, required bool pinned}) async {
    return _datasource.setPinned(
      chatId,
      pinned,
      limit: MessengerRepository.pinnedChatLimit,
    );
  }

  @override
  Future<void> markChatRead({required String chatId}) async {
    _datasource.markChatRead(chatId);
  }

  @override
  Future<void> deleteChat({
    required String chatId,
    bool forEveryone = false,
  }) async {
    _datasource.deleteChat(chatId);
  }

  @override
  Future<List<User>> getContactableUsers() =>
      _datasource.fetchContactableUsers();

  @override
  Future<ChatSummary> openChatWith(User user) => _datasource.openChatWith(user);

  @override
  Future<ChatSummary> openSavedMessages() async =>
      _datasource.openSavedMessages();

  @override
  Future<List<User>> searchContacts(String query) async =>
      _datasource.searchContacts(query);

  @override
  Future<List<MessageHit>> searchMessages(String query) async =>
      _datasource.searchMessages(query);

  @override
  Future<ChatSummary> openChatByUsername(String username) =>
      _datasource.openChatByUsername(username);
}
