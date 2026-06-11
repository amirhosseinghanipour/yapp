import '../entities/auth_session.dart';

class AuthException implements Exception {
  const AuthException(this.code, [this.message]);

  final AuthErrorCode code;
  final String? message;

  @override
  String toString() =>
      'AuthException($code${message == null ? '' : ': $message'})';
}

enum AuthErrorCode {
  invalidKey,
  invalidSignature,
  invalidUsername,
  usernameTaken,
  challengeExpired,
  unknownHandle,
  rateLimited,
  network,
  unknown,
}

abstract class AuthRepository {
  Future<void> init();

  AuthSession? get currentSession;

  Stream<AuthSession?> watchSession();

  Future<bool> hasLocalIdentity();

  Future<String> registerNewAccount({String? username});

  Future<void> restoreFromMnemonic(String mnemonic);

  Future<void> logout();

  Future<String> buildLinkDeviceQr({
    required String httpUrl,
    required String wsUrl,
  });

  Future<void> completeLinkDeviceFromBundle(String encoded);
}
