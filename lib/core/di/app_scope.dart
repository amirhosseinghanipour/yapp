import 'package:flutter/material.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/messages/domain/repositories/messenger_repository.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    required this.messengerRepository,
    required this.profileRepository,
    required this.settingsRepository,
    required this.authRepository,
    required super.child,
    super.key,
  });

  final MessengerRepository messengerRepository;
  final ProfileRepository profileRepository;
  final SettingsRepository settingsRepository;
  final AuthRepository authRepository;

  static MessengerRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.messengerRepository;
  }

  static ProfileRepository profileOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.profileRepository;
  }

  static SettingsRepository settingsOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.settingsRepository;
  }

  static AuthRepository authOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in context');
    return scope!.authRepository;
  }

  @override
  bool updateShouldNotify(covariant AppScope oldWidget) =>
      messengerRepository != oldWidget.messengerRepository ||
      profileRepository != oldWidget.profileRepository ||
      settingsRepository != oldWidget.settingsRepository ||
      authRepository != oldWidget.authRepository;
}
