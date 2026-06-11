import 'dart:typed_data';

import '../entities/attachment.dart';
import '../entities/chat_summary.dart';
import '../entities/current_user.dart';
import '../entities/message.dart';
import '../entities/message_hit.dart';
import '../entities/message_type.dart';
import '../entities/reply_preview.dart';
import '../entities/user.dart';

class SendMessageException implements Exception {
  const SendMessageException(this.message, {this.recoverable = true});
  final String message;
  final bool recoverable;
  @override
  String toString() => message;
}

abstract class MessengerRepository {
  static const int pinnedChatLimit = 3;

  Future<CurrentUser> getCurrentUser();

  Future<List<ChatSummary>> getChatSummaries();

  Stream<List<ChatSummary>> watchChatSummaries();

  Future<List<Message>> getMessages(String chatId);

  Stream<List<Message>> watchMessages(String chatId);

  Future<bool> isPeerTyping(String chatId);

  Stream<bool> watchPeerTyping(String chatId);

  void sendTyping({required String chatId, required bool isTyping});

  Future<User> fetchPeerWithPresence(String peerAccountId);

  Stream<User> watchPeerPresence(String peerAccountId);

  Future<Uint8List?> loadPeerAvatar(User peer);

  Future<void> announceProfileToActiveChats();

  Future<Message> sendText({
    required String chatId,
    required String text,
    ReplyPreview? replyTo,
  });

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
  });

  Future<Message> sendLocation({
    required String chatId,
    required double lat,
    required double lng,
    String? caption,
  });

  Future<Uint8List> downloadMedia(Attachment attachment);

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  });

  Future<void> editText({
    required String chatId,
    required String messageId,
    required String newText,
  });

  Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  });

  Future<Message> forwardMessage({
    required String sourceChatId,
    required String messageId,
    required String destinationChatId,
  });

  Future<void> setMuted({required String chatId, required bool muted});

  Future<bool> setPinned({required String chatId, required bool pinned});

  Future<void> markChatRead({required String chatId});

  Future<void> deleteChat({required String chatId, bool forEveryone = false});

  Future<void> setPinnedMessage({
    required String chatId,
    required String? messageId,
  });

  Future<void> setDraft({required String chatId, required String text});
  Future<String> getDraft(String chatId);

  Future<List<User>> getContactableUsers();

  Future<ChatSummary> openSavedMessages();

  Future<List<MessageHit>> searchMessages(String query);

  Future<List<User>> searchContacts(String query);

  Future<ChatSummary> openChatWith(User user);

  Future<ChatSummary> openChatByUsername(String username);
}
