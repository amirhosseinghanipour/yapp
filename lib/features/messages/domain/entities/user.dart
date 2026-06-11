import '../../../../core/crypto/encrypted_blob_store.dart';

class User {
  const User({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
    this.username,
    this.lastSeenAt,
    this.avatarBlob,
    this.bio,
  });

  final String id;
  final String name;
  final String? username;
  final String avatarUrl;
  final bool isOnline;

  final String? bio;

  final DateTime? lastSeenAt;

  final EncryptedBlobRef? avatarBlob;

  User copyWith({
    String? name,
    String? username,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeenAt,
    EncryptedBlobRef? avatarBlob,
    String? bio,
  }) => User(
    id: id,
    name: name ?? this.name,
    username: username ?? this.username,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    isOnline: isOnline ?? this.isOnline,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    avatarBlob: avatarBlob ?? this.avatarBlob,
    bio: bio ?? this.bio,
  );
}
