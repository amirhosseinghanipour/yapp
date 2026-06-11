import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'base64url.dart';

class LinkDeviceBundle {
  LinkDeviceBundle({
    required this.challengeId,
    required this.nonce,
    required this.accountId,
    required this.httpUrl,
    required this.wsUrl,
    this.identityCipher,
  });

  final String challengeId;
  final String nonce;
  final String accountId;
  final String httpUrl;
  final String wsUrl;
  final String? identityCipher;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': 1,
    'challengeId': challengeId,
    'nonce': nonce,
    'accountId': accountId,
    'httpUrl': httpUrl,
    'wsUrl': wsUrl,
    if (identityCipher != null) 'identityCipher': identityCipher,
  };

  static LinkDeviceBundle fromJson(Map<String, dynamic> json) {
    if ((json['v'] as int? ?? 0) != 1) {
      throw const FormatException('Unsupported link bundle version');
    }
    return LinkDeviceBundle(
      challengeId: json['challengeId'] as String,
      nonce: json['nonce'] as String,
      accountId: json['accountId'] as String,
      httpUrl: json['httpUrl'] as String,
      wsUrl: json['wsUrl'] as String,
      identityCipher: json['identityCipher'] as String?,
    );
  }

  static LinkDeviceBundle parse(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return fromJson(json);
  }

  String encode() => jsonEncode(toJson());

  static Future<String> encryptIdentitySeed({
    required Uint8List identitySeed,
    required Uint8List nonce,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(nonce),
      info: utf8.encode('yapp:v1:link-device-qr'),
    );
    final aes = AesGcm.with256bits();
    final iv = Uint8List.fromList(
      List<int>.generate(12, (i) => (i * 17 + 3) & 255),
    );
    final box = await aes.encrypt(identitySeed, secretKey: key, nonce: iv);
    return encodeBase64Url(<int>[...iv, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> decryptIdentitySeed({
    required String cipherB64,
    required Uint8List nonce,
  }) async {
    final raw = decodeBase64Url(cipherB64);
    if (raw.length < 12 + 16) {
      throw const FormatException('Invalid identity cipher');
    }
    final iv = Uint8List.fromList(raw.sublist(0, 12));
    final rest = raw.sublist(12);
    final cipherText = rest.sublist(0, rest.length - 16);
    final mac = Mac(rest.sublist(rest.length - 16));
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final key = await hkdf.deriveKey(
      secretKey: SecretKey(nonce),
      info: utf8.encode('yapp:v1:link-device-qr'),
    );
    final aes = AesGcm.with256bits();
    final plain = await aes.decrypt(
      SecretBox(cipherText, nonce: iv, mac: mac),
      secretKey: key,
    );
    return Uint8List.fromList(plain);
  }
}
