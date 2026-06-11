import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'base64url.dart';

final _aes = AesGcm.with256bits();

class ProfileCipher {
  ProfileCipher(this._secretKey);

  final SecretKey _secretKey;

  static Future<ProfileCipher> fromIdentitySeed(Uint8List identitySeed) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(identitySeed),
      info: utf8.encode('yapp:v1:profile'),
    );
    return ProfileCipher(key);
  }

  Future<String> encrypt(Map<String, dynamic> profile) async {
    final r = Random.secure();
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => r.nextInt(256)),
    );
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(profile)),
      secretKey: _secretKey,
      nonce: nonce,
    );
    return encodeBase64Url([...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  Future<Map<String, dynamic>> decrypt(String? raw) async {
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    final bytes = decodeBase64Url(raw);
    if (bytes.length < 28) return <String, dynamic>{};
    final nonce = bytes.sublist(0, 12);
    final mac = Mac(bytes.sublist(bytes.length - 16));
    final cipher = bytes.sublist(12, bytes.length - 16);
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: mac),
      secretKey: _secretKey,
    );
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }
}
