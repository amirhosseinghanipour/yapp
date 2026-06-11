import 'package:intl/intl.dart';

String formatRelativeTime(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) {
    return 'now';
  }
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return m == 1 ? '1 min' : '$m min';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return h == 1 ? '1 hour' : '$h hours';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return d == 1 ? '1 day' : '$d days';
  }
  return DateFormat.MMMd().format(time);
}

String formatMessageClock(DateTime time) {
  return DateFormat('HH:mm').format(time);
}
