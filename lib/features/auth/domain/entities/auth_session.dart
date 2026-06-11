class AuthSession {
  const AuthSession({
    required this.accountId,
    required this.deviceId,
    this.username,
  });

  final String accountId;
  final String deviceId;
  final String? username;

  String get displayLabel =>
      username != null ? '@$username' : accountId.substring(0, 8);
}
