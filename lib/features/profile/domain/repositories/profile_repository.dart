import 'dart:typed_data';

import '../entities/my_profile.dart';

abstract class ProfileRepository {
  void invalidateProfile();

  Future<MyProfile> getMyProfile({bool forceRefresh = false});

  Stream<MyProfile> watchProfile();

  Future<MyProfile> updateProfile({
    String? displayName,
    String? username,
    bool unsetUsername = false,
    String? bio,
    bool unsetBio = false,
    String? phoneDisplay,
    bool unsetPhoneDisplay = false,
  });

  Future<MyProfile> updateAvatar(String localPath);

  Future<MyProfile> removeAvatar();

  Future<Uint8List?> loadAvatarBytes(MyProfile profile);

  String shareLinkFor(MyProfile profile);
}
