import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal/libsignal.dart';

import '../base64url.dart';
import '../sealed_payload.dart';
import 'libsignal_identity.dart';
import 'libsignal_stores.dart';

class LibsignalPeerBundle {
  LibsignalPeerBundle({required this.signalDeviceId, required this.bundle});
  final int signalDeviceId;
  final PreKeyBundle bundle;
}

typedef PeerBundleFetcher =
    Future<List<LibsignalPeerBundle>> Function(String peerAccountId);

abstract interface class SenderCertProvider {
  Future<Uint8List> senderCertificate();
  Uint8List get trustRoot;
}

class DeviceCiphertext {
  DeviceCiphertext({required this.signalDeviceId, required this.ciphertextB64});
  final int signalDeviceId;
  final String ciphertextB64;
}

class LibsignalEngine {
  LibsignalEngine({
    required String selfAccountId,
    required int selfSignalDeviceId,
    required LibsignalIdentity identity,
    required PeerBundleFetcher fetchPeerBundles,
    required SenderCertProvider certProvider,
  }) : _self = ProtocolAddress(
         name: selfAccountId,
         deviceId: selfSignalDeviceId,
       ),
       _identity = identity,
       _fetchPeerBundles = fetchPeerBundles,
       _certProvider = certProvider;

  final ProtocolAddress _self;
  final LibsignalIdentity _identity;
  final PeerBundleFetcher _fetchPeerBundles;
  final SenderCertProvider _certProvider;

  final _sessions = PersistentSessionStore();
  final _preKeys = PersistentPreKeyStore();
  final _signedPreKeys = PersistentSignedPreKeyStore();
  final _kyberPreKeys = PersistentKyberPreKeyStore();

  PersistentIdentityKeyStore get _identityStore => _identity.identityStore();

  SealedSenderCipher get _cipher => SealedSenderCipher(
    localAddress: _self,
    sessionStore: _sessions,
    identityKeyStore: _identityStore,
    preKeyStore: _preKeys,
    signedPreKeyStore: _signedPreKeys,
    kyberPreKeyStore: _kyberPreKeys,
  );

  Future<List<DeviceCiphertext>> encryptForAllDevices({
    required String peerAccountId,
    required SealedMessagePayload payload,
  }) async {
    final bundles = await _fetchPeerBundles(peerAccountId);
    if (bundles.isEmpty) {
      throw StateError('No device bundles for $peerAccountId');
    }
    final cert = await _certProvider.senderCertificate();
    final plaintext = Uint8List.fromList(
      utf8.encode(jsonEncode(payload.toJson())),
    );

    final out = <DeviceCiphertext>[];
    for (final b in bundles) {
      final peer = ProtocolAddress(
        name: peerAccountId,
        deviceId: b.signalDeviceId,
      );
      if (!await _sessions.containsSession(peer)) {
        await SessionBuilder(
          localAddress: _self,
          sessionStore: _sessions,
          identityKeyStore: _identityStore,
        ).processPreKeyBundle(peer, b.bundle);
      }
      final sealed = await _cipher.encrypt(
        recipientAddress: peer,
        plaintext: plaintext,
        senderCertificate: cert,
      );
      out.add(
        DeviceCiphertext(
          signalDeviceId: b.signalDeviceId,
          ciphertextB64: encodeBase64Url(sealed),
        ),
      );
    }
    return out;
  }

  Future<SealedMessagePayload> decryptSealed(String ciphertextB64) async {
    final result = await _cipher.decrypt(
      ciphertext: decodeBase64Url(ciphertextB64),
      trustRoot: _certProvider.trustRoot,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    final sealed = SealedMessagePayload.tryParseUtf8(result.plaintext);
    if (sealed == null) throw const FormatException('invalid sealed payload');
    if (sealed.senderAccountId != result.senderAddress.name()) {
      throw StateError('sender mismatch');
    }
    return sealed;
  }
}
