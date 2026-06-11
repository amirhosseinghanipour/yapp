import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:libsignal/libsignal.dart';

import '../base64url.dart';
import 'libsignal_stores.dart';

class SignedPreKeyUpload {
  SignedPreKeyUpload(this.keyId, this.publicKeyB64, this.signatureB64);
  final int keyId;
  final String publicKeyB64;
  final String signatureB64;
}

class KyberPreKeyUpload {
  KyberPreKeyUpload(this.keyId, this.publicKeyB64, this.signatureB64);
  final int keyId;
  final String publicKeyB64;
  final String signatureB64;
}

class OneTimePreKeyUpload {
  OneTimePreKeyUpload(this.keyId, this.publicKeyB64);
  final int keyId;
  final String publicKeyB64;
}

class PreKeyUploadBundle {
  PreKeyUploadBundle({
    required this.identityKeyB64,
    required this.registrationId,
    required this.signed,
    required this.kyber,
    required this.oneTime,
  });
  final String identityKeyB64;
  final int registrationId;
  final SignedPreKeyUpload signed;
  final KyberPreKeyUpload kyber;
  final List<OneTimePreKeyUpload> oneTime;
}

class LibsignalIdentity {
  LibsignalIdentity._({
    required Uint8List identityPrivateBytes,
    required this.registrationId,
  }) : _privBytes = identityPrivateBytes;

  final Uint8List _privBytes;
  final int registrationId;

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await LibSignal.init();
    _initialized = true;
  }

  static Future<LibsignalIdentity> fromSeed(Uint8List identitySeed) async {
    await ensureInitialized();
    final privBytes = await _hkdf(
      identitySeed,
      'yapp:libsignal:identity:v1',
      32,
    );
    final regBytes = await _hkdf(
      identitySeed,
      'yapp:libsignal:registration:v1',
      2,
    );
    final registrationId = ((regBytes[0] << 8 | regBytes[1]) % 16380) + 1;
    return LibsignalIdentity._(
      identityPrivateBytes: privBytes,
      registrationId: registrationId,
    );
  }

  Uint8List identityPublicKey() {
    final priv = PrivateKey.deserialize(bytes: _privBytes);
    return IdentityKeyPair.fromKeys(
      privateKey: priv,
      publicKey: priv.getPublicKey(),
    ).publicKey;
  }

  PersistentIdentityKeyStore identityStore() => PersistentIdentityKeyStore(
    identityPrivateBytes: _privBytes,
    registrationId: registrationId,
  );

  Future<PreKeyUploadBundle> generatePreKeys({
    int signedId = 1,
    int kyberId = 1,
    int startId = 1,
    int oneTimeCount = 100,
  }) async {
    final now = BigInt.from(DateTime.now().millisecondsSinceEpoch);

    final signedPriv = PrivateKey.generate();
    final signedPubObj = signedPriv.getPublicKey();
    final signedPubBytes = signedPubObj.serialize();
    final signedSig = PrivateKey.deserialize(
      bytes: _privBytes,
    ).sign(message: signedPubBytes);
    await PersistentSignedPreKeyStore().storeSignedPreKey(
      signedId,
      SignedPreKeyRecord(
        id: signedId,
        timestamp: now,
        publicKey: signedPubObj,
        privateKey: signedPriv,
        signature: signedSig,
      ),
    );

    final kyberPair = KyberKeyPair.generate();
    final kyberPubBytes = kyberPair.getPublicKey().serialize();
    final kyberSig = PrivateKey.deserialize(
      bytes: _privBytes,
    ).sign(message: kyberPubBytes);
    await PersistentKyberPreKeyStore().storeKyberPreKey(
      kyberId,
      KyberPreKeyRecord.create(
        id: kyberId,
        timestamp: now,
        keyPair: kyberPair,
        signature: kyberSig,
      ),
    );

    final preKeyStore = PersistentPreKeyStore();
    final oneTime = <OneTimePreKeyUpload>[];
    for (var i = 0; i < oneTimeCount; i++) {
      final id = startId + i;
      final priv = PrivateKey.generate();
      final pubObj = priv.getPublicKey();
      final pubBytes = pubObj.serialize();
      await preKeyStore.storePreKey(
        id,
        PreKeyRecord(id: id, publicKey: pubObj, privateKey: priv),
      );
      oneTime.add(OneTimePreKeyUpload(id, encodeBase64Url(pubBytes)));
    }

    return PreKeyUploadBundle(
      identityKeyB64: encodeBase64Url(identityPublicKey()),
      registrationId: registrationId,
      signed: SignedPreKeyUpload(
        signedId,
        encodeBase64Url(signedPubBytes),
        encodeBase64Url(signedSig),
      ),
      kyber: KyberPreKeyUpload(
        kyberId,
        encodeBase64Url(kyberPubBytes),
        encodeBase64Url(kyberSig),
      ),
      oneTime: oneTime,
    );
  }
}

Future<Uint8List> _hkdf(Uint8List seed, String info, int length) async {
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: length);
  final out = await hkdf.deriveKey(
    secretKey: SecretKey(seed),
    nonce: const <int>[],
    info: utf8.encode(info),
  );
  return Uint8List.fromList(await out.extractBytes());
}
