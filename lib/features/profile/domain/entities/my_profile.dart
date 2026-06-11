import '../../../../core/crypto/encrypted_blob_store.dart';
import '../../../messages/domain/entities/current_user.dart';

class MyProfile {
  const MyProfile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    this.avatarBlob,
    this.username,
    this.bio,
    this.phoneDisplay,
  });

  final String id;
  final String displayName;

  final String avatarUrl;

  final EncryptedBlobRef? avatarBlob;

  final String? username;
  final String? bio;
  final String? phoneDisplay;

  bool get hasAvatar => avatarBlob != null || avatarUrl.isNotEmpty;

  factory MyProfile.fromCurrentUser(CurrentUser user) {
    return MyProfile(
      id: user.id,
      displayName: user.name,
      avatarUrl: user.avatarUrl,
      username: user.username,
      bio: user.bio,
      phoneDisplay: user.phoneDisplay,
    );
  }

  MyProfile copyWith({
    String? displayName,
    String? avatarUrl,
    Object? avatarBlob = _unset,
    Object? username = _unset,
    Object? bio = _unset,
    Object? phoneDisplay = _unset,
  }) {
    return MyProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBlob: identical(avatarBlob, _unset)
          ? this.avatarBlob
          : avatarBlob as EncryptedBlobRef?,
      username: identical(username, _unset)
          ? this.username
          : username as String?,
      bio: identical(bio, _unset) ? this.bio : bio as String?,
      phoneDisplay: identical(phoneDisplay, _unset)
          ? this.phoneDisplay
          : phoneDisplay as String?,
    );
  }
}

const Object _unset = Object();
