import 'dart:typed_data';

import 'base64url.dart';

class CanonicalPayloads {
  static String register({
    required Uint8List nonce,
    required Uint8List identityPublicKey,
    String? username,
  }) {
    final u = username?.trim().toLowerCase() ?? '';
    return [
      'yapp:v1:register',
      encodeBase64Url(nonce),
      encodeBase64Url(identityPublicKey),
      u,
    ].join('\n');
  }

  static String auth({required Uint8List nonce, required String deviceId}) {
    return ['yapp:v1:auth', encodeBase64Url(nonce), deviceId].join('\n');
  }

  static String linkDevice({
    required Uint8List nonce,
    required Uint8List devicePublicKey,
  }) {
    return [
      'yapp:v1:link-device',
      encodeBase64Url(nonce),
      encodeBase64Url(devicePublicKey),
    ].join('\n');
  }

  static String signedPreKey({
    required int keyId,
    required Uint8List publicKey,
  }) {
    return [
      'yapp:v1:signed-prekey',
      keyId.toString(),
      encodeBase64Url(publicKey),
    ].join('\n');
  }

  static String recover({required Uint8List nonce, required String accountId}) {
    return ['yapp:v1:recover', encodeBase64Url(nonce), accountId].join('\n');
  }
}
