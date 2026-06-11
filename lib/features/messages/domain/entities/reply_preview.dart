import 'message_type.dart';

class ReplyPreview {
  const ReplyPreview({
    required this.messageId,
    required this.senderName,
    required this.type,
    this.text,
    this.thumbnailUrl,
  });

  final String messageId;
  final String senderName;
  final MessageType type;
  final String? text;
  final String? thumbnailUrl;
}
