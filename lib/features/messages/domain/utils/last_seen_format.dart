String formatLastSeenLabel({required bool isOnline, DateTime? lastSeenAt}) {
  if (isOnline) return 'online';
  if (lastSeenAt == null) return 'last seen recently';
  final now = DateTime.now();
  final diff = now.difference(lastSeenAt);
  if (diff.isNegative) return 'last seen recently';
  if (diff.inMinutes < 2) return 'last seen just now';
  if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'last seen ${diff.inHours}h ago';
  if (diff.inDays < 7) return 'last seen ${diff.inDays}d ago';
  return 'last seen ${lastSeenAt.year}-${lastSeenAt.month.toString().padLeft(2, '0')}-${lastSeenAt.day.toString().padLeft(2, '0')}';
}
