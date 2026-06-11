import 'chat_list_kind.dart';
import 'user.dart';

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.user,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    this.kind = ChatListKind.dm,
    this.isPinned = false,
    this.isMuted = false,
    this.pinnedMessageId,
    this.draft = '',
  });

  final String id;
  final User user;
  final ChatListKind kind;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;

  final String? pinnedMessageId;

  final String draft;

  ChatSummary copyWith({
    ChatListKind? kind,
    String? lastMessage,
    DateTime? timestamp,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    String? pinnedMessageId,
    bool clearPinnedMessage = false,
    String? draft,
  }) {
    return ChatSummary(
      id: id,
      user: user,
      kind: kind ?? this.kind,
      lastMessage: lastMessage ?? this.lastMessage,
      timestamp: timestamp ?? this.timestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      pinnedMessageId: clearPinnedMessage
          ? null
          : (pinnedMessageId ?? this.pinnedMessageId),
      draft: draft ?? this.draft,
    );
  }
}
