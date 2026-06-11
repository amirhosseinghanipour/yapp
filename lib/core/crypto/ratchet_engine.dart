import 'dart:typed_data';

import '../storage/local_messenger_db.dart';
import 'sealed_payload.dart';
import 'signal_session.dart';

abstract class RatchetEngine {
  Future<String> encrypt({
    required String peerAccountId,
    required SealedMessagePayload payload,
  });

  Future<SealedMessagePayload> decryptInbound(String ciphertextB64);
}

typedef SignedPreKeyFetcher = Future<Uint8List> Function(String peerAccountId);

class LegacyRatchetEngine implements RatchetEngine {
  LegacyRatchetEngine({required SignedPreKeyFetcher fetchSignedPreKey})
    : _fetchSignedPreKey = fetchSignedPreKey;

  final SignedPreKeyFetcher _fetchSignedPreKey;
  final _db = LocalMessengerDb.instance;

  @override
  Future<String> encrypt({
    required String peerAccountId,
    required SealedMessagePayload payload,
  }) async {
    final spk = await _fetchSignedPreKey(peerAccountId);
    final hasSession = await _db.signalSessionState(peerAccountId) != null;
    final session = await SignalSession.loadOrCreate(
      peerAccountId: peerAccountId,
      peerSignedPreKeyPublic: spk,
    );
    return hasSession
        ? session.encryptSealed(payload)
        : session.encryptFirstSealed(
            payload: payload,
            peerSignedPreKeyPublic: spk,
          );
  }

  @override
  Future<SealedMessagePayload> decryptInbound(String ciphertextB64) =>
      SignalSession.decryptInbound(ciphertextB64);
}
