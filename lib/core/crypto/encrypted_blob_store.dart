import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'base64url.dart';

class EncryptedBlobRef {
  EncryptedBlobRef({
    required this.objectKey,
    required this.keyB64,
    required this.nonceB64,
    required this.size,
    this.mime,
  });

  final String objectKey;
  final String keyB64;
  final String nonceB64;
  final int size;
  final String? mime;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'objectKey': objectKey,
    'key': keyB64,
    'nonce': nonceB64,
    'size': size,
    if (mime != null) 'mime': mime,
  };

  static EncryptedBlobRef fromJson(Map<String, dynamic> j) => EncryptedBlobRef(
    objectKey: j['objectKey'] as String,
    keyB64: j['key'] as String,
    nonceB64: j['nonce'] as String,
    size: (j['size'] as num?)?.toInt() ?? 0,
    mime: j['mime'] as String?,
  );
}

class EncryptedBlobStore {
  EncryptedBlobStore({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String bucket = 'media';
  static final _aes = AesGcm.with256bits();
  static final _rng = Random.secure();
  static const _uuid = Uuid();

  static Uint8List _random(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

  Future<EncryptedBlobRef> upload(Uint8List plaintext, {String? mime}) async {
    final key = _random(32);
    final nonce = _random(12);
    final box = await _aes.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final blob = BytesBuilder()
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    final objectKey = '${_uuid.v4()}/${_uuid.v4()}';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          objectKey,
          blob.toBytes(),
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
            upsert: false,
          ),
        );
    return EncryptedBlobRef(
      objectKey: objectKey,
      keyB64: encodeBase64Url(key),
      nonceB64: encodeBase64Url(nonce),
      size: plaintext.length,
      mime: mime,
    );
  }

  Future<Uint8List> download(EncryptedBlobRef ref) async {
    final blob = await _client.storage.from(bucket).download(ref.objectKey);
    if (blob.length < 16) throw const FormatException('blob too short');
    final ct = blob.sublist(0, blob.length - 16);
    final mac = blob.sublist(blob.length - 16);
    final clear = await _aes.decrypt(
      SecretBox(ct, nonce: decodeBase64Url(ref.nonceB64), mac: Mac(mac)),
      secretKey: SecretKey(decodeBase64Url(ref.keyB64)),
    );
    return Uint8List.fromList(clear);
  }

  Future<void> remove(String objectKey) async {
    try {
      await _client.storage.from(bucket).remove(<String>[objectKey]);
    } catch (_) {}
  }
}
