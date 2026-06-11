import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal/libsignal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../storage/identity_vault.dart';
import '../../supabase/pg_bytea.dart';
import '../base64url.dart';
import '../ratchet_engine.dart';
import '../sealed_payload.dart';
import 'libsignal_db.dart';
import 'libsignal_identity.dart';
import 'libsignal_stores.dart';

class LibsignalRatchetEngine implements RatchetEngine {
  LibsignalRatchetEngine({
    required String selfAccountId,
    required SupabaseClient client,
    IdentityVault? vault,
  }) : _selfAccountId = selfAccountId,
       _client = client,
       _vault = vault ?? IdentityVault() {
    LibsignalDb.useAccount(selfAccountId);
  }

  final String _selfAccountId;
  final SupabaseClient _client;
  final IdentityVault _vault;

  LibsignalIdentity? _identity;
  int _selfDeviceId = 1;

  ProtocolAddress get _self =>
      ProtocolAddress(name: _selfAccountId, deviceId: _selfDeviceId);

  final _sessions = PersistentSessionStore();
  final _preKeys = PersistentPreKeyStore();
  final _signedPreKeys = PersistentSignedPreKeyStore();
  final _kyberPreKeys = PersistentKyberPreKeyStore();

  Future<void> _ensureInit() async {
    if (_identity != null) return;
    final seed = (await _vault.loadOrThrow()).identitySeed;
    _identity = await LibsignalIdentity.fromSeed(seed);
    final sid = await LibsignalDb.instance.get('self', 'signal_device_id');
    _selfDeviceId = sid != null ? int.parse(utf8.decode(sid)) : 1;
  }

  PersistentIdentityKeyStore get _identityStore => _identity!.identityStore();

  SessionCipher _cipher() => SessionCipher(
    localAddress: _self,
    sessionStore: _sessions,
    identityKeyStore: _identityStore,
    preKeyStore: _preKeys,
    signedPreKeyStore: _signedPreKeys,
    kyberPreKeyStore: _kyberPreKeys,
  );

  @override
  Future<String> encrypt({
    required String peerAccountId,
    required SealedMessagePayload payload,
  }) async {
    await _ensureInit();
    final (peer, bundle) = await _claimPrimaryBundle(peerAccountId);
    if (!await _sessions.containsSession(peer)) {
      await SessionBuilder(
        localAddress: _self,
        sessionStore: _sessions,
        identityKeyStore: _identityStore,
      ).processPreKeyBundle(peer, bundle);
    }
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(payload.toJson())),
    );
    final msg = await _cipher().encrypt(peer, plaintext);
    return _encodeFrame(
      msg.type.value,
      _selfAccountId,
      _selfDeviceId,
      msg.ciphertext,
    );
  }

  @override
  Future<SealedMessagePayload> decryptInbound(String ciphertextB64) async {
    await _ensureInit();
    final frame = _decodeFrame(decodeBase64Url(ciphertextB64));
    final sender = ProtocolAddress(
      name: frame.sender,
      deviceId: frame.senderDeviceId,
    );
    final msg = CiphertextMessage.fromRaw(
      messageType: frame.msgType,
      ciphertext: frame.ciphertext,
    );
    final clear = await _cipher().decrypt(sender, msg);
    final sealed = SealedMessagePayload.tryParseUtf8(clear);
    if (sealed == null) throw const FormatException('invalid sealed payload');
    if (sealed.senderAccountId != frame.sender) {
      throw StateError('sender mismatch');
    }
    return sealed;
  }

  Future<(ProtocolAddress, PreKeyBundle)> _claimPrimaryBundle(
    String peerAccountId,
  ) async {
    final rows = await _client.rpc<List<dynamic>>(
      'claim_prekey_bundle',
      params: <String, dynamic>{'p_account': peerAccountId},
    );
    if (rows.isEmpty) {
      throw StateError('No libsignal bundle for $peerAccountId');
    }
    final r = rows.first as Map<String, dynamic>;

    final signalDeviceId = r['signal_device_id'] as int;
    final peer = ProtocolAddress(name: peerAccountId, deviceId: signalDeviceId);
    final bundle = PreKeyBundle(
      registrationId: r['registration_id'] as int,
      deviceId: signalDeviceId,
      preKeyId: r['onetime_key_id'] as int?,
      preKeyPublic: r['onetime_public_key'] == null
          ? null
          : decodePgBase64(r['onetime_public_key'] as String),
      signedPreKeyId: r['signed_key_id'] as int,
      signedPreKeyPublic: decodePgBase64(r['signed_public_key'] as String),
      signedPreKeySignature: decodePgBase64(r['signed_signature'] as String),
      identityKey: decodeBase64Url(r['identity_public_key'] as String),
      kyberPreKeyId: r['kyber_key_id'] as int,
      kyberPreKeyPublic: decodePgBase64(r['kyber_public_key'] as String),
      kyberPreKeySignature: decodePgBase64(r['kyber_signature'] as String),
    );
    return (peer, bundle);
  }

  String _encodeFrame(
    int msgType,
    String sender,
    int senderDeviceId,
    Uint8List ciphertext,
  ) {
    final name = utf8.encode(sender);
    final out = BytesBuilder()
      ..addByte(msgType & 0xff)
      ..addByte(senderDeviceId & 0xff)
      ..addByte((name.length >> 8) & 0xff)
      ..addByte(name.length & 0xff)
      ..add(name)
      ..add(ciphertext);
    return encodeBase64Url(out.toBytes());
  }

  _Frame _decodeFrame(Uint8List raw) {
    if (raw.length < 4) throw const FormatException('frame too short');
    final nameLen = (raw[2] << 8) | raw[3];
    final nameEnd = 4 + nameLen;
    if (raw.length < nameEnd) throw const FormatException('frame truncated');
    return _Frame(
      raw[0],
      utf8.decode(raw.sublist(4, nameEnd)),
      raw[1],
      Uint8List.fromList(raw.sublist(nameEnd)),
    );
  }
}

class _Frame {
  _Frame(this.msgType, this.sender, this.senderDeviceId, this.ciphertext);
  final int msgType;
  final String sender;
  final int senderDeviceId;
  final Uint8List ciphertext;
}
