import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../crypto/identity_crypto.dart';

class IdentityVault {
  IdentityVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _identitySeedKey = 'yapp.identity.seed';
  static const _deviceSeedKey = 'yapp.device.seed';
  static const _accountIdKey = 'yapp.account.id';
  static const _signedPreKeySeedKey = 'yapp.signal.signed_prekey.seed';

  Future<bool> hasIdentity() async {
    final seed = await _storage.read(key: _identitySeedKey);
    return seed != null && seed.isNotEmpty;
  }

  Future<IdentityMaterial> loadOrThrow() async {
    final identityHex = await _storage.read(key: _identitySeedKey);
    final deviceHex = await _storage.read(key: _deviceSeedKey);
    if (identityHex == null || deviceHex == null) {
      throw StateError('No identity on device');
    }
    return IdentityMaterial.fromSeeds(
      identitySeed: _hexToBytes(identityHex),
      deviceSeed: _hexToBytes(deviceHex),
    );
  }

  Future<void> saveIdentity(IdentityMaterial material) async {
    await _storage.write(
      key: _identitySeedKey,
      value: _bytesToHex(material.identitySeed),
    );
    await _storage.write(
      key: _deviceSeedKey,
      value: _bytesToHex(material.deviceSeed),
    );
  }

  Future<String?> readAccountId() => _storage.read(key: _accountIdKey);

  Future<void> writeAccountId(String accountId) =>
      _storage.write(key: _accountIdKey, value: accountId);

  Future<void> saveSignedPreKeySeed(Uint8List seed) async {
    if (seed.length != 32) throw ArgumentError('pre-key seed must be 32 bytes');
    await _storage.write(key: _signedPreKeySeedKey, value: _bytesToHex(seed));
  }

  Future<Uint8List?> readSignedPreKeySeed() async {
    final hex = await _storage.read(key: _signedPreKeySeedKey);
    if (hex == null || hex.isEmpty) return null;
    return _hexToBytes(hex);
  }

  Future<void> clear() async {
    await _storage.delete(key: _identitySeedKey);
    await _storage.delete(key: _deviceSeedKey);
    await _storage.delete(key: _accountIdKey);
    await _storage.delete(key: _signedPreKeySeedKey);
  }

  String mnemonicForSeed(Uint8List identitySeed) {
    return bip39.entropyToMnemonic(_bytesToHex(identitySeed));
  }

  Future<IdentityMaterial> materialFromMnemonic(String phrase) async {
    final normalized = phrase.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (!bip39.validateMnemonic(normalized)) {
      throw FormatException('Invalid recovery phrase');
    }
    final hex = bip39.mnemonicToEntropy(normalized);
    final identitySeed = _hexToBytes(hex);
    return IdentityMaterial.fromSeeds(
      identitySeed: identitySeed,
      deviceSeed: _randomSeed32(),
    );
  }
}

String _bytesToHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _hexToBytes(String hex) {
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

Uint8List _randomSeed32() {
  final r = Random.secure();
  return Uint8List.fromList(List<int>.generate(32, (_) => r.nextInt(256)));
}
