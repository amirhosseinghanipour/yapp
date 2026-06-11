class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.username,
    this.bio,
    this.phoneDisplay,
  });

  final String id;
  final String name;
  final String avatarUrl;

  final String? username;
  final String? bio;

  final String? phoneDisplay;
}
