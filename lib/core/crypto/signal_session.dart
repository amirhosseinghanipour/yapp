import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../storage/identity_vault.dart';
import '../storage/local_messenger_db.dart';
import 'base64url.dart';
import 'sealed_payload.dart';

class SignalSession {
  SignalSession._({
    required this.peerAccountId,
    required Uint8List sendChainKey,
    Uint8List? recvChainKey,
    int sendCounter = 0,
    int recvCounter = 0,
  }) : _sendChainKey = sendChainKey,
       _recvChainKey = recvChainKey,
       _sendCounter = sendCounter,
       _recvCounter = recvCounter;

  final String peerAccountId;
  Uint8List _sendChainKey;
  Uint8List? _recvChainKey;
  int _sendCounter;
  int _recvCounter;

  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();

  static const int _frameHandshake = 0x01;
  static const int _frameRatchet = 0x02;

  static Future<SignalSession> loadOrCreate({
    required String peerAccountId,
    required Uint8List peerSignedPreKeyPublic,
  }) async {
    final stored = await LocalMessengerDb.instance.signalSessionState(
      peerAccountId,
    );
    if (stored != null) {
      return _importState(peerAccountId, decodeBase64Url(stored));
    }
    final ephemeral = await newSignalEphemeral();
    final root = await _rootFromEphemeral(
      ephemeralPrivate: ephemeral.ephemeralPrivate,
      peerSignedPreKeyPublic: peerSignedPreKeyPublic,
    );
    final half = await _splitRoot(root);
    final session = SignalSession._(
      peerAccountId: peerAccountId,
      sendChainKey: half.$1,
      recvChainKey: half.$2,
    );
    await session._persist();
    return session;
  }

  Future<String> encryptFirstSealed({
    required SealedMessagePayload payload,
    required Uint8List peerSignedPreKeyPublic,
  }) async {
    final ephemeral = await newSignalEphemeral();
    final root = await _rootFromEphemeral(
      ephemeralPrivate: ephemeral.ephemeralPrivate,
      peerSignedPreKeyPublic: peerSignedPreKeyPublic,
    );
    final half = await _splitRoot(root);
    _sendChainKey = half.$1;
    _recvChainKey = half.$2;
    _sendCounter = 0;
    _recvCounter = 0;

    final inner = await _encryptPayloadBytes(
      utf8.encode(jsonEncode(payload.toJson())),
    );
    final out = BytesBuilder();
    out.addByte(_frameHandshake);
    out.add(ephemeral.ephemeralPublic);
    out.add(inner);
    await _persist();
    return encodeBase64Url(out.toBytes());
  }

  Future<String> encryptSealed(SealedMessagePayload payload) async {
    final inner = await _encryptPayloadBytes(
      utf8.encode(jsonEncode(payload.toJson())),
    );
    final out = BytesBuilder()
      ..addByte(_frameRatchet)
      ..add(inner);
    await _persist();
    return encodeBase64Url(out.toBytes());
  }

  static Future<SealedMessagePayload> decryptInbound(
    String ciphertextB64,
  ) async {
    final raw = decodeBase64Url(ciphertextB64);
    if (raw.isEmpty) throw const FormatException('empty ciphertext');

    if (raw[0] == _frameHandshake) {
      if (raw.length < 1 + 32 + 1 + 12 + 16) {
        throw const FormatException('handshake frame too short');
      }
      final epub = raw.sublist(1, 33);
      final spkSeed = await IdentityVault().readSignedPreKeySeed();
      if (spkSeed == null) throw StateError('No signed pre-key on device');
      final root = await _rootFromResponder(
        signedPreKeyPrivate: spkSeed,
        senderEphemeralPublic: epub,
      );
      final half = await _splitRoot(root);
      final session = SignalSession._(
        peerAccountId: '_unknown',
        sendChainKey: half.$2,
        recvChainKey: half.$1,
        sendCounter: 0,
        recvCounter: 0,
      );
      final clear = await session._decryptPayloadBytes(raw.sublist(33));
      final sealed = session._parseSealed(clear);
      await LocalMessengerDb.instance.saveSignalSession(
        sealed.senderAccountId,
        encodeBase64Url(await session._exportState()),
      );
      return sealed;
    }

    final peers = await LocalMessengerDb.instance.allPeers();
    for (final peer in peers) {
      final state = await LocalMessengerDb.instance.signalSessionState(peer.id);
      if (state == null) continue;
      try {
        final session = _importState(peer.id, decodeBase64Url(state));
        return await session.decryptSealed(ciphertextB64);
      } catch (_) {
        continue;
      }
    }
    throw StateError('no session for ratchet frame');
  }

  Future<SealedMessagePayload> decryptSealed(String ciphertextB64) async {
    final raw = decodeBase64Url(ciphertextB64);
    if (raw.isEmpty) throw const FormatException('empty ciphertext');

    if (raw[0] == _frameHandshake) {
      if (raw.length < 1 + 32 + 1 + 12 + 16) {
        throw const FormatException('handshake frame too short');
      }
      final epub = raw.sublist(1, 33);
      final spkSeed = await IdentityVault().readSignedPreKeySeed();
      if (spkSeed == null) throw StateError('No signed pre-key on device');
      final root = await _rootFromResponder(
        signedPreKeyPrivate: spkSeed,
        senderEphemeralPublic: epub,
      );
      final half = await _splitRoot(root);
      _recvChainKey = half.$1;
      _sendChainKey = half.$2;
      _sendCounter = 0;
      _recvCounter = 0;
      final clear = await _decryptPayloadBytes(raw.sublist(33));
      await _persist();
      return _parseSealed(clear);
    }

    if (raw[0] == _frameRatchet) {
      final clear = await _decryptPayloadBytes(raw.sublist(1));
      return _parseSealed(clear);
    }

    throw const FormatException('unknown signal frame');
  }

  SealedMessagePayload _parseSealed(List<int> clear) {
    final sealed = SealedMessagePayload.tryParseUtf8(clear);
    if (sealed == null) {
      throw const FormatException('invalid sealed inner payload');
    }
    return sealed;
  }

  Future<List<int>> _encryptPayloadBytes(List<int> plain) async {
    final messageKey = await _nextSendKey();
    final counter = _sendCounter - 1;
    final nonce = _nonceForCounter(counter);
    final box = await _aes.encrypt(
      plain,
      secretKey: SecretKey(messageKey),
      nonce: nonce,
    );
    final out = BytesBuilder();
    out.addByte(counter);
    out.add(nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.toBytes();
  }

  Future<List<int>> _decryptPayloadBytes(List<int> frame) async {
    if (_recvChainKey == null) throw StateError('recv chain missing');
    if (frame.length < 1 + 12 + 16) {
      throw const FormatException('ratchet frame short');
    }
    final counter = frame[0];
    final nonce = Uint8List.fromList(frame.sublist(1, 13));
    final mac = Mac(Uint8List.fromList(frame.sublist(frame.length - 16)));
    final cipherText = Uint8List.fromList(frame.sublist(13, frame.length - 16));
    final messageKey = await _recvKeyForCounter(counter);
    final clear = await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: SecretKey(messageKey),
    );
    if (counter >= _recvCounter) _recvCounter = counter + 1;
    return clear;
  }

  Future<Uint8List> _nextSendKey() async {
    final key = await _hkdf(
      _sendChainKey,
      info: utf8.encode('yapp:v1:send:$_sendCounter'),
      length: 32,
    );
    _sendChainKey = await _hkdf(
      _sendChainKey,
      info: utf8.encode('yapp:v1:send-chain'),
      length: 32,
    );
    _sendCounter += 1;
    return key;
  }

  Future<Uint8List> _recvKeyForCounter(int counter) async {
    return _hkdf(
      _recvChainKey!,
      info: utf8.encode('yapp:v1:recv:$counter'),
      length: 32,
    );
  }

  static Uint8List _nonceForCounter(int counter) {
    final n = Uint8List(12);
    n[11] = counter & 0xff;
    n[10] = (counter >> 8) & 0xff;
    return n;
  }

  static Future<Uint8List> _rootFromEphemeral({
    required Uint8List ephemeralPrivate,
    required Uint8List peerSignedPreKeyPublic,
  }) async {
    final kp = await _x25519.newKeyPairFromSeed(ephemeralPrivate);
    final peer = SimplePublicKey(
      peerSignedPreKeyPublic,
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: kp,
      remotePublicKey: peer,
    );
    return Uint8List.fromList(await shared.extractBytes());
  }

  static Future<Uint8List> _rootFromResponder({
    required Uint8List signedPreKeyPrivate,
    required Uint8List senderEphemeralPublic,
  }) async {
    final kp = await _x25519.newKeyPairFromSeed(signedPreKeyPrivate);
    final peer = SimplePublicKey(
      senderEphemeralPublic,
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: kp,
      remotePublicKey: peer,
    );
    return Uint8List.fromList(await shared.extractBytes());
  }

  static Future<(Uint8List, Uint8List)> _splitRoot(Uint8List root) async {
    final material = await _hkdf(
      root,
      info: utf8.encode('yapp:v1:split'),
      length: 64,
    );
    return (material.sublist(0, 32), material.sublist(32, 64));
  }

  static Future<Uint8List> _hkdf(
    Uint8List ikm, {
    required List<int> info,
    required int length,
  }) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: length);
    final out = await hkdf.deriveKey(
      secretKey: SecretKey(ikm),
      info: info,
      nonce: Uint8List(0),
    );
    return Uint8List.fromList(await out.extractBytes());
  }

  Future<void> _persist() async {
    await LocalMessengerDb.instance.saveSignalSession(
      peerAccountId,
      encodeBase64Url(await _exportState()),
    );
  }

  Future<Uint8List> _exportState() async {
    final buf = BytesBuilder();
    buf.add(_sendChainKey);
    buf.addByte(_sendCounter);
    if (_recvChainKey != null) {
      buf.addByte(1);
      buf.add(_recvChainKey!);
      buf.addByte(_recvCounter);
    } else {
      buf.addByte(0);
    }
    return buf.toBytes();
  }

  static SignalSession _importState(String peerAccountId, Uint8List bytes) {
    var i = 0;
    final sendKey = bytes.sublist(i, i + 32);
    i += 32;
    final sendCounter = bytes[i];
    i += 1;
    final hasRecv = bytes[i] == 1;
    i += 1;
    Uint8List? recvKey;
    var recvCounter = 0;
    if (hasRecv) {
      recvKey = bytes.sublist(i, i + 32);
      i += 32;
      recvCounter = bytes[i];
    }
    return SignalSession._(
      peerAccountId: peerAccountId,
      sendChainKey: sendKey,
      recvChainKey: recvKey,
      sendCounter: sendCounter,
      recvCounter: recvCounter,
    );
  }
}

Future<({Uint8List ephemeralPrivate, Uint8List ephemeralPublic})>
newSignalEphemeral() async {
  final kp = await X25519().newKeyPair();
  final seed = Uint8List.fromList(await kp.extractPrivateKeyBytes());
  final pub = await kp.extractPublicKey();
  return (
    ephemeralPrivate: seed,
    ephemeralPublic: Uint8List.fromList(pub.bytes),
  );
}
