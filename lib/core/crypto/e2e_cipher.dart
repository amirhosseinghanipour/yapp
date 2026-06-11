import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'base64url.dart';

final _x25519 = X25519();
final _aes = AesGcm.with256bits();
final _secureRandom = Random.secure();

class E2eSession {
  E2eSession._(this._secretKey);

  final SecretKey _secretKey;

  static Future<E2eSession> fromSharedSecret(Uint8List shared32) async {
    if (shared32.length != 32) {
      throw ArgumentError('Shared secret must be 32 bytes');
    }
    return E2eSession._(SecretKey(shared32));
  }

  static Future<E2eSession> deriveFromPreKeyBundle({
    required SimpleKeyPair ephemeral,
    required Uint8List peerSignedPreKeyPublic,
  }) async {
    final peerPublic = SimplePublicKey(
      peerSignedPreKeyPublic,
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: ephemeral,
      remotePublicKey: peerPublic,
    );
    final bytes = await shared.extractBytes();
    return E2eSession.fromSharedSecret(Uint8List.fromList(bytes));
  }

  static Future<({SimpleKeyPair ephemeral, Uint8List publicBytes})>
  newEphemeral() async {
    final kp = await _x25519.newKeyPair();
    final pub = await kp.extractPublicKey();
    return (ephemeral: kp, publicBytes: Uint8List.fromList(pub.bytes));
  }

  Future<String> encryptJsonAsync(Map<String, dynamic> payload) async {
    final plaintext = utf8.encode(jsonEncode(payload));
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => _secureRandom.nextInt(256)),
    );
    final box = await _aes.encrypt(
      plaintext,
      secretKey: _secretKey,
      nonce: nonce,
    );
    final macBytes = box.mac.bytes;
    final cipherLen = box.cipherText.length;
    final out = Uint8List(1 + 12 + cipherLen + macBytes.length);
    out[0] = 1;
    out.setRange(1, 13, nonce);
    out.setRange(13, 13 + cipherLen, box.cipherText);
    out.setRange(13 + cipherLen, out.length, macBytes);
    return encodeBase64Url(out);
  }

  Future<Uint8List> exportKeyBytes() async {
    return Uint8List.fromList(await _secretKey.extractBytes());
  }

  static Future<E2eSession> importKeyBytes(Uint8List bytes) =>
      E2eSession.fromSharedSecret(bytes);

  Future<Map<String, dynamic>> decryptJsonAsync(String ciphertextB64) async {
    final raw = decodeBase64Url(ciphertextB64);
    if (raw.isEmpty || raw[0] != 1) {
      throw FormatException('Unknown cipher version');
    }
    final nonce = raw.sublist(1, 13);
    final mac = Mac(raw.sublist(raw.length - 16));
    final cipherText = raw.sublist(13, raw.length - 16);
    final clear = await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: _secretKey,
    );
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }
}

Future<Uint8List> generateX25519PublicKey() async {
  final kp = await _x25519.newKeyPair();
  final pub = await kp.extractPublicKey();
  return Uint8List.fromList(pub.bytes);
}

Future<SimpleKeyPair> newX25519KeyPair() => _x25519.newKeyPair();
