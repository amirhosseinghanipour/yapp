import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../storage/identity_vault.dart';
import '../../supabase/pg_bytea.dart';
import '../base64url.dart';
import 'libsignal_db.dart';
import 'libsignal_identity.dart';

Future<void> publishLibsignalKeys({
  required SupabaseClient client,
  required String accountId,
  required String deviceId,
  IdentityVault? vault,
  int oneTimeCount = 50,
}) async {
  LibsignalDb.useAccount(accountId);
  final v = vault ?? IdentityVault();
  final seed = (await v.loadOrThrow()).identitySeed;
  final identity = await LibsignalIdentity.fromSeed(seed);
  final bundle = await identity.generatePreKeys(oneTimeCount: oneTimeCount);

  final sid = await client.rpc<dynamic>(
    'set_libsignal_identity',
    params: <String, dynamic>{
      'p_identity_key': bundle.identityKeyB64,
      'p_registration_id': bundle.registrationId,
    },
  );
  final signalDeviceId = (sid as num).toInt();
  await LibsignalDb.instance.put(
    'self',
    'signal_device_id',
    Uint8List.fromList(utf8.encode('$signalDeviceId')),
  );

  Uint8List b(String b64url) => decodeBase64Url(b64url);
  final rows = <Map<String, dynamic>>[
    <String, dynamic>{
      'account_id': accountId,
      'device_id': deviceId,
      'kind': 'signed',
      'key_id': bundle.signed.keyId,
      'public_key': bytesToPgHex(b(bundle.signed.publicKeyB64)),
      'signature': bytesToPgHex(b(bundle.signed.signatureB64)),
    },
    <String, dynamic>{
      'account_id': accountId,
      'device_id': deviceId,
      'kind': 'kyber',
      'key_id': bundle.kyber.keyId,
      'public_key': bytesToPgHex(b(bundle.kyber.publicKeyB64)),
      'signature': bytesToPgHex(b(bundle.kyber.signatureB64)),
    },
    for (final ot in bundle.oneTime)
      <String, dynamic>{
        'account_id': accountId,
        'device_id': deviceId,
        'kind': 'onetime',
        'key_id': ot.keyId,
        'public_key': bytesToPgHex(b(ot.publicKeyB64)),
        'signature': null,
      },
  ];
  await client.from('prekeys').insert(rows);
}
