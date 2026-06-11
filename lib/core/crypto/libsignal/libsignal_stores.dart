import 'dart:typed_data';

import 'package:libsignal/libsignal.dart';

import 'libsignal_db.dart';

String _addrKey(ProtocolAddress a) => '${a.name()}:${a.deviceId()}';

class PersistentSessionStore implements SessionStore {
  final _db = LibsignalDb.instance;
  static const _kind = 'session';

  @override
  Future<SessionRecord?> loadSession(ProtocolAddress address) async {
    final bytes = await _db.get(_kind, _addrKey(address));
    return bytes == null ? null : SessionRecord.deserialize(bytes: bytes);
  }

  @override
  Future<void> storeSession(ProtocolAddress address, SessionRecord record) =>
      _db.put(_kind, _addrKey(address), record.serialize());

  @override
  Future<bool> containsSession(ProtocolAddress address) =>
      _db.contains(_kind, _addrKey(address));

  @override
  Future<void> deleteSession(ProtocolAddress address) =>
      _db.delete(_kind, _addrKey(address));

  @override
  Future<void> deleteAllSessions(String name) async {
    for (final k in await _db.keys(_kind)) {
      if (k.startsWith('$name:')) await _db.delete(_kind, k);
    }
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final out = <int>[];
    for (final k in await _db.keys(_kind)) {
      if (k.startsWith('$name:')) {
        final id = int.tryParse(k.substring(name.length + 1));
        if (id != null) out.add(id);
      }
    }
    return out;
  }
}

class PersistentPreKeyStore implements PreKeyStore {
  final _db = LibsignalDb.instance;
  static const _kind = 'prekey';

  @override
  Future<PreKeyRecord?> loadPreKey(int preKeyId) async {
    final bytes = await _db.get(_kind, '$preKeyId');
    return bytes == null ? null : PreKeyRecord.deserialize(bytes: bytes);
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) =>
      _db.put(_kind, '$preKeyId', record.serialize());

  @override
  Future<bool> containsPreKey(int preKeyId) => _db.contains(_kind, '$preKeyId');

  @override
  Future<void> removePreKey(int preKeyId) => _db.delete(_kind, '$preKeyId');

  @override
  Future<List<int>> getAllPreKeyIds() async =>
      (await _db.keys(_kind)).map(int.parse).toList(growable: false);
}

class PersistentSignedPreKeyStore implements SignedPreKeyStore {
  final _db = LibsignalDb.instance;
  static const _kind = 'signed_prekey';

  @override
  Future<SignedPreKeyRecord?> loadSignedPreKey(int signedPreKeyId) async {
    final bytes = await _db.get(_kind, '$signedPreKeyId');
    return bytes == null ? null : SignedPreKeyRecord.deserialize(bytes: bytes);
  }

  @override
  Future<void> storeSignedPreKey(
    int signedPreKeyId,
    SignedPreKeyRecord record,
  ) => _db.put(_kind, '$signedPreKeyId', record.serialize());

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) =>
      _db.contains(_kind, '$signedPreKeyId');

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) =>
      _db.delete(_kind, '$signedPreKeyId');

  @override
  Future<List<int>> getAllSignedPreKeyIds() async =>
      (await _db.keys(_kind)).map(int.parse).toList(growable: false);
}

class PersistentKyberPreKeyStore implements KyberPreKeyStore {
  final _db = LibsignalDb.instance;
  static const _kind = 'kyber_prekey';
  static const _usedKind = 'kyber_used';

  @override
  Future<KyberPreKeyRecord?> loadKyberPreKey(int kyberPreKeyId) async {
    final bytes = await _db.get(_kind, '$kyberPreKeyId');
    return bytes == null ? null : KyberPreKeyRecord.deserialize(bytes: bytes);
  }

  @override
  Future<void> storeKyberPreKey(int kyberPreKeyId, KyberPreKeyRecord record) =>
      _db.put(_kind, '$kyberPreKeyId', record.serialize());

  @override
  Future<bool> containsKyberPreKey(int kyberPreKeyId) =>
      _db.contains(_kind, '$kyberPreKeyId');

  @override
  Future<void> markKyberPreKeyUsed(int kyberPreKeyId) =>
      _db.put(_usedKind, '$kyberPreKeyId', Uint8List.fromList(<int>[1]));

  @override
  Future<void> removeKyberPreKey(int kyberPreKeyId) =>
      _db.delete(_kind, '$kyberPreKeyId');

  @override
  Future<List<int>> getAllKyberPreKeyIds() async =>
      (await _db.keys(_kind)).map(int.parse).toList(growable: false);
}

class PersistentIdentityKeyStore implements IdentityKeyStore {
  PersistentIdentityKeyStore({
    required Uint8List identityPrivateBytes,
    required int registrationId,
  }) : _privBytes = identityPrivateBytes,
       _registrationId = registrationId;

  final Uint8List _privBytes;
  final int _registrationId;
  final _db = LibsignalDb.instance;
  static const _kind = 'identity';

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    final priv = PrivateKey.deserialize(bytes: _privBytes);
    return IdentityKeyPair.fromKeys(
      privateKey: priv,
      publicKey: priv.getPublicKey(),
    );
  }

  @override
  Future<int> getLocalRegistrationId() async => _registrationId;

  @override
  Future<bool> saveIdentity(
    ProtocolAddress address,
    PublicKey identityKey,
  ) async {
    final key = _addrKey(address);
    final existing = await _db.get(_kind, key);
    final incoming = identityKey.serialize();
    final changed = existing == null || !_bytesEqual(existing, incoming);
    if (changed) {
      await _db.put(_kind, key, incoming);
      if (existing != null) {
        await _db.put(
          'key_changed',
          address.name(),
          Uint8List.fromList(<int>[1]),
        );
        await _db.delete('safety_verified', address.name());
      }
    }
    return changed;
  }

  @override
  Future<PublicKey?> getIdentity(ProtocolAddress address) async {
    final bytes = await _db.get(_kind, _addrKey(address));
    return bytes == null ? null : PublicKey.deserialize(bytes: bytes);
  }

  @override
  Future<bool> isTrustedIdentity(
    ProtocolAddress address,
    PublicKey identityKey,
    Direction direction,
  ) async {
    final stored = await _db.get(_kind, _addrKey(address));
    if (stored == null) return true;
    return true;
  }
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
