import 'dart:async';

import 'package:yapp/features/auth/domain/entities/auth_session.dart';
import 'package:yapp/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryFake implements AuthRepository {
  @override
  AuthSession? get currentSession => null;

  @override
  Future<bool> hasLocalIdentity() async => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<String> registerNewAccount({String? username}) async => '';

  @override
  Future<void> restoreFromMnemonic(String mnemonic) async {}

  @override
  Stream<AuthSession?> watchSession() => const Stream<AuthSession?>.empty();

  @override
  Future<String> buildLinkDeviceQr({
    required String httpUrl,
    required String wsUrl,
  }) async => '';

  @override
  Future<void> completeLinkDeviceFromBundle(String encoded) async {}
}
