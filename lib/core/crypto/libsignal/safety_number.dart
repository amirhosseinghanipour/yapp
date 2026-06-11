import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal/libsignal.dart';

import 'libsignal_db.dart';
import 'libsignal_identity.dart';

class SafetyNumber {
  static const int _iterations = 5200;
  static const int _version = 2;
  static const String _verifiedKind = 'safety_verified';

  static Future<String> compute({
    required String selfAccountId,
    required Uint8List selfIdentityKey,
    required String peerAccountId,
    required Uint8List peerIdentityKey,
  }) async {
    await LibsignalIdentity.ensureInitialized();
    final fp = Fingerprint(
      iterations: _iterations,
      version: _version,
      localIdentifier: utf8.encode(selfAccountId),
      localPublicKey: selfIdentityKey,
      remoteIdentifier: utf8.encode(peerAccountId),
      remotePublicKey: peerIdentityKey,
    );
    return _group(fp.displayString());
  }

  static Future<Uint8List> scannable({
    required String selfAccountId,
    required Uint8List selfIdentityKey,
    required String peerAccountId,
    required Uint8List peerIdentityKey,
  }) async {
    await LibsignalIdentity.ensureInitialized();
    return Fingerprint(
      iterations: _iterations,
      version: _version,
      localIdentifier: utf8.encode(selfAccountId),
      localPublicKey: selfIdentityKey,
      remoteIdentifier: utf8.encode(peerAccountId),
      remotePublicKey: peerIdentityKey,
    ).scannableEncoding();
  }

  static Future<bool> hasKeyChanged(String peerAccountId) =>
      LibsignalDb.instance.contains('key_changed', peerAccountId);

  static Future<void> acknowledgeKeyChange(String peerAccountId) =>
      LibsignalDb.instance.delete('key_changed', peerAccountId);

  static Future<bool> isVerified(String peerAccountId) =>
      LibsignalDb.instance.contains(_verifiedKind, peerAccountId);

  static Future<void> setVerified(String peerAccountId, bool verified) async {
    if (verified) {
      await LibsignalDb.instance.put(
        _verifiedKind,
        peerAccountId,
        Uint8List.fromList(<int>[1]),
      );
    } else {
      await LibsignalDb.instance.delete(_verifiedKind, peerAccountId);
    }
  }

  static String _group(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i += 5) {
      if (i > 0) buf.write(' ');
      buf.write(digits.substring(i, (i + 5).clamp(0, digits.length)));
    }
    return buf.toString();
  }
}
