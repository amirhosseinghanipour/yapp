import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'base64url.dart';
import 'canonical.dart';

final _ed25519 = Ed25519();
final _secureRandom = Random.secure();

class IdentityMaterial {
  IdentityMaterial({
    required this.identitySeed,
    required this.deviceSeed,
    required this.identityKeyPair,
    required this.deviceKeyPair,
  });

  final Uint8List identitySeed;
  final Uint8List deviceSeed;
  final SimpleKeyPair identityKeyPair;
  final SimpleKeyPair deviceKeyPair;

  Future<Uint8List> identityPublicKeyBytes() async {
    final pub = await identityKeyPair.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }

  Future<Uint8List> devicePublicKeyBytes() async {
    final pub = await deviceKeyPair.extractPublicKey();
    return Uint8List.fromList(pub.bytes);
  }

  static Future<IdentityMaterial> generate() async {
    return IdentityMaterial.fromSeeds(
      identitySeed: _randomSeed32(),
      deviceSeed: _randomSeed32(),
    );
  }

  static Future<IdentityMaterial> fromSeeds({
    required Uint8List identitySeed,
    required Uint8List deviceSeed,
  }) async {
    if (identitySeed.length != 32 || deviceSeed.length != 32) {
      throw ArgumentError('Ed25519 seeds must be 32 bytes');
    }
    final identityKeyPair = await _ed25519.newKeyPairFromSeed(identitySeed);
    final deviceKeyPair = await _ed25519.newKeyPairFromSeed(deviceSeed);
    return IdentityMaterial(
      identitySeed: identitySeed,
      deviceSeed: deviceSeed,
      identityKeyPair: identityKeyPair,
      deviceKeyPair: deviceKeyPair,
    );
  }

  Future<String> signRegister({
    required Uint8List nonce,
    String? username,
  }) async {
    final pub = await identityPublicKeyBytes();
    final message = CanonicalPayloads.register(
      nonce: nonce,
      identityPublicKey: pub,
      username: username,
    );
    return _signUtf8(identityKeyPair, message);
  }

  Future<String> signAuth({
    required Uint8List nonce,
    required String deviceId,
  }) async {
    final message = CanonicalPayloads.auth(nonce: nonce, deviceId: deviceId);
    return _signUtf8(identityKeyPair, message);
  }

  Future<String> signLinkDevice({required Uint8List nonce}) async {
    final devicePub = await devicePublicKeyBytes();
    final message = CanonicalPayloads.linkDevice(
      nonce: nonce,
      devicePublicKey: devicePub,
    );
    return _signUtf8(identityKeyPair, message);
  }

  Future<String> signRecover({
    required Uint8List nonce,
    required String accountId,
  }) async {
    final message = CanonicalPayloads.recover(
      nonce: nonce,
      accountId: accountId,
    );
    return _signUtf8(identityKeyPair, message);
  }

  Future<String> signSignedPreKey({
    required int keyId,
    required Uint8List x25519Public,
  }) async {
    final message = CanonicalPayloads.signedPreKey(
      keyId: keyId,
      publicKey: x25519Public,
    );
    return _signUtf8(identityKeyPair, message);
  }

  Future<String> publicKeyB64() async =>
      encodeBase64Url(await identityPublicKeyBytes());

  Future<String> devicePublicKeyB64() async =>
      encodeBase64Url(await devicePublicKeyBytes());
}

Future<String> _signUtf8(SimpleKeyPair keyPair, String message) async {
  final sig = await _ed25519.sign(message.codeUnits, keyPair: keyPair);
  return encodeBase64Url(sig.bytes);
}

Uint8List _randomSeed32() {
  return Uint8List.fromList(
    List<int>.generate(32, (_) => _secureRandom.nextInt(256)),
  );
}
