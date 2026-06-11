import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yapp/core/di/app_scope.dart';
import 'package:yapp/features/auth/presentation/auth_gate.dart';
import 'package:yapp/features/messages/data/repositories/messenger_repository_impl.dart';
import 'package:yapp/features/profile/domain/entities/my_profile.dart';
import 'package:yapp/features/profile/domain/repositories/profile_repository.dart';
import 'package:yapp/features/settings/data/repositories/settings_repository_impl.dart';

import 'auth_repository_fake.dart';

void main() {
  testWidgets('Auth gate renders onboarding when signed out', (
    WidgetTester tester,
  ) async {
    final auth = AuthRepositoryFake();
    await tester.pumpWidget(
      AppScope(
        messengerRepository: MessengerRepositoryImpl(),
        profileRepository: _TestProfileRepository(),
        settingsRepository: SettingsRepositoryImpl(),
        authRepository: auth,
        child: MaterialApp(home: AuthGate(repository: auth)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('yapp'), findsOneWidget);
  });
}

class _TestProfileRepository implements ProfileRepository {
  static final _profile = MyProfile(
    id: 'test',
    displayName: 'Test',
    username: 'test',
    bio: '',
    avatarUrl: '',
    phoneDisplay: null,
  );

  @override
  void invalidateProfile() {}

  @override
  Future<MyProfile> getMyProfile({bool forceRefresh = false}) async => _profile;

  @override
  Stream<MyProfile> watchProfile() => Stream.value(_profile);

  @override
  Future<MyProfile> updateProfile({
    String? displayName,
    String? username,
    bool unsetUsername = false,
    String? bio,
    bool unsetBio = false,
    String? phoneDisplay,
    bool unsetPhoneDisplay = false,
  }) async => _profile;

  @override
  Future<MyProfile> updateAvatar(String avatarUrl) async => _profile;

  @override
  Future<MyProfile> removeAvatar() async => _profile;

  @override
  Future<Uint8List?> loadAvatarBytes(MyProfile profile) async => null;

  @override
  String shareLinkFor(MyProfile profile) => 'https://yapp.test/@test';
}
