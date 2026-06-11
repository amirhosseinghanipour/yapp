import 'chat_summary.dart';
import 'message.dart';

class MessageHit {
  const MessageHit({required this.summary, required this.message});

  final ChatSummary summary;
  final Message message;
}
