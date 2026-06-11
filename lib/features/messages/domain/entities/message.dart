import 'attachment.dart';
import 'message_status.dart';
import 'message_type.dart';
import 'reply_preview.dart';

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.type,
    required this.timestamp,
    this.text,
    this.attachment,
    this.replyTo,
    this.status = MessageStatus.sent,
    this.editedAt,
    this.reactions = const <String, List<String>>{},
    this.forwardedFromName,
    this.noForward = false,
  });

  final String id;
  final String senderId;
  final MessageType type;
  final DateTime timestamp;
  final String? text;
  final Attachment? attachment;
  final ReplyPreview? replyTo;
  final MessageStatus status;
  final DateTime? editedAt;
  final Map<String, List<String>> reactions;
  final String? forwardedFromName;

  final bool noForward;

  bool get isMedia => type != MessageType.text;

  Message copyWith({
    String? id,
    MessageStatus? status,
    DateTime? editedAt,
    String? text,
    Attachment? attachment,
    Map<String, List<String>>? reactions,
    String? forwardedFromName,
    bool? noForward,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId,
      type: type,
      timestamp: timestamp,
      text: text ?? this.text,
      attachment: attachment ?? this.attachment,
      replyTo: replyTo,
      status: status ?? this.status,
      editedAt: editedAt ?? this.editedAt,
      reactions: reactions ?? this.reactions,
      forwardedFromName: forwardedFromName ?? this.forwardedFromName,
      noForward: noForward ?? this.noForward,
    );
  }
}
