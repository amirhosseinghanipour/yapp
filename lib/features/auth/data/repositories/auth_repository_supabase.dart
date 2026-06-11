import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../../core/crypto/base64url.dart';
import '../../../../core/crypto/identity_crypto.dart';
import '../../../../core/crypto/link_device_bundle.dart';
import '../../../../core/graphql/auth_refresh.dart';
import '../../../../core/graphql/device_platform.dart';
import '../../../../core/graphql/token_storage.dart';
import '../../../../core/storage/identity_vault.dart';
import '../../../../core/supabase/auth_api.dart';
import '../../../../core/crypto/libsignal/libsignal_prekey_publisher.dart';
import '../../../../core/supabase/realtime_relay.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositorySupabase implements AuthRepository {
  AuthRepositorySupabase({
    required SupabaseClient client,
    required SupabaseAuthApi authApi,
    required TokenStorage tokenStorage,
    IdentityVault? vault,
  }) : _client = client,
       _api = authApi,
       _tokens = tokenStorage,
       _vault = vault ?? IdentityVault();

  final SupabaseClient _client;
  final SupabaseAuthApi _api;
  final TokenStorage _tokens;
  final IdentityVault _vault;

  AuthSession? _current;
  final _sessionCtrl = StreamController<AuthSession?>.broadcast();
  RealtimeRelay? _relay;
  StreamSubscription<Map<String, dynamic>>? _revokedSub;

  @override
  AuthSession? get currentSession => _current;

  @override
  Future<void> init() async {
    if (!await _vault.hasIdentity()) {
      _emit(null);
      return;
    }
    final refresh = await _tokens.readRefreshToken();
    final deviceId = await _tokens.readDeviceId();
    if (refresh != null && deviceId != null) {
      try {
        final payload = await _api.refresh(
          deviceId: deviceId,
          refreshToken: refresh,
        );
        await _persistTokens(payload);
        _emit(
          AuthSession(
            accountId: payload['accountId'] as String,
            deviceId: payload['deviceId'] as String,
          ),
        );
        return;
      } on AuthException {
        // ignore: empty_catches
      }
    }
    _emit(null);
  }

  @override
  Stream<AuthSession?> watchSession() => _sessionCtrl.stream;

  @override
  Future<bool> hasLocalIdentity() => _vault.hasIdentity();

  @override
  Future<String> registerNewAccount({String? username}) async {
    final material = await IdentityMaterial.generate();
    await _vault.saveIdentity(material);

    final begin = await _api.beginRegistration();
    final nonce = decodeBase64Url(begin['nonce'] as String, expectedLen: 32);
    final identitySig = await material.signRegister(
      nonce: nonce,
      username: username,
    );
    final payload = await _api.finishRegistration(
      challengeId: begin['challengeId'] as String,
      identityPublicKey: await material.publicKeyB64(),
      identitySignature: identitySig,
      username: username,
      devicePublicKey: await material.devicePublicKeyB64(),
      deviceName: 'Yapp',
      platform: devicePlatformForGraphQL(),
    );

    await _persistTokens(payload);
    await _uploadPreKeyBundle(payload);
    final mnemonic = _vault.mnemonicForSeed(material.identitySeed);
    _emit(
      AuthSession(
        accountId: payload['accountId'] as String,
        deviceId: payload['deviceId'] as String,
        username: username,
      ),
    );
    return mnemonic;
  }

  @override
  Future<void> restoreFromMnemonic(String mnemonic) async {
    final material = await _vault.materialFromMnemonic(mnemonic);
    await _vault.saveIdentity(material);
    final pub = await material.publicKeyB64();

    final begin = await _api.beginRecovery(identityPublicKey: pub);
    final nonce = decodeBase64Url(begin['nonce'] as String, expectedLen: 32);
    final accountId = begin['accountId'] as String;
    final sig = await material.signRecover(nonce: nonce, accountId: accountId);

    final payload = await _api.finishRecovery(
      challengeId: begin['challengeId'] as String,
      accountId: accountId,
      identitySignature: sig,
      devicePublicKey: await material.devicePublicKeyB64(),
      deviceName: 'Yapp',
      platform: devicePlatformForGraphQL(),
    );

    await _persistTokens(payload);
    await _uploadPreKeyBundle(payload);
    _emit(
      AuthSession(
        accountId: payload['accountId'] as String,
        deviceId: payload['deviceId'] as String,
      ),
    );
  }

  @override
  Future<String> buildLinkDeviceQr({
    required String httpUrl,
    required String wsUrl,
  }) async {
    final accessToken = await _tokens.readAccessToken();
    if (accessToken == null) {
      throw const AuthException(AuthErrorCode.unknown, 'Not authenticated');
    }
    final begin = await _api.beginLinkDevice(accessToken: accessToken);
    final material = await _vault.loadOrThrow();
    final nonce = decodeBase64Url(begin['nonce'] as String, expectedLen: 32);
    final cipher = await LinkDeviceBundle.encryptIdentitySeed(
      identitySeed: material.identitySeed,
      nonce: nonce,
    );
    return LinkDeviceBundle(
      challengeId: begin['challengeId'] as String,
      nonce: begin['nonce'] as String,
      accountId: begin['accountId'] as String,
      httpUrl: httpUrl,
      wsUrl: wsUrl,
      identityCipher: cipher,
    ).encode();
  }

  @override
  Future<void> completeLinkDeviceFromBundle(String encoded) async {
    final bundle = LinkDeviceBundle.parse(encoded);
    if (bundle.identityCipher == null) {
      throw const AuthException(
        AuthErrorCode.invalidKey,
        'Missing identity in QR',
      );
    }
    final nonce = decodeBase64Url(bundle.nonce, expectedLen: 32);
    final identitySeed = await LinkDeviceBundle.decryptIdentitySeed(
      cipherB64: bundle.identityCipher!,
      nonce: nonce,
    );
    final fresh = await IdentityMaterial.generate();
    final material = await IdentityMaterial.fromSeeds(
      identitySeed: identitySeed,
      deviceSeed: fresh.deviceSeed,
    );
    await _vault.saveIdentity(material);
    final sig = await material.signLinkDevice(nonce: nonce);
    final payload = await _api.finishLinkDevice(
      challengeId: bundle.challengeId,
      accountId: bundle.accountId,
      identitySignature: sig,
      devicePublicKey: await material.devicePublicKeyB64(),
      deviceName: 'Yapp',
      platform: devicePlatformForGraphQL(),
    );
    await _persistTokens(payload);
    await _uploadPreKeyBundle(payload);
    _emit(
      AuthSession(
        accountId: payload['accountId'] as String,
        deviceId: payload['deviceId'] as String,
      ),
    );
  }

  @override
  Future<void> logout() async {
    await _teardownRevokedWatch();
    try {
      await _client.rpc<void>('unregister_push_token');
    } catch (_) {}
    try {
      final accessToken = await _tokens.readAccessToken();
      final deviceId = await _tokens.readDeviceId();
      if (accessToken != null && deviceId != null) {
        await _api.logout(accessToken: accessToken, deviceId: deviceId);
      }
    } catch (_) {}
    await _tokens.clear();
    await _vault.clear();
    _emit(null);
  }

  Future<void> _persistTokens(Map<String, dynamic> payload) async {
    await persistAuthPayload(_tokens, payload);
    await _vault.writeAccountId(payload['accountId'] as String);
  }

  Future<void> _uploadPreKeyBundle(Map<String, dynamic> payload) {
    return publishLibsignalKeys(
      client: _client,
      accountId: payload['accountId'] as String,
      deviceId: payload['deviceId'] as String,
      vault: _vault,
    );
  }

  Future<void> _watchSessionRevoked() async {
    await _teardownRevokedWatch();
    final session = _current;
    if (session == null) return;
    final relay = RealtimeRelay(client: _client, accountId: session.accountId)
      ..connect();
    _relay = relay;
    _revokedSub = relay.sessionRevoked.listen((raw) {
      final revokedDevice = raw['deviceId'] as String?;
      if (revokedDevice == null || revokedDevice == session.deviceId) {
        unawaited(logout());
      }
    });
  }

  Future<void> _teardownRevokedWatch() async {
    await _revokedSub?.cancel();
    _revokedSub = null;
    await _relay?.disconnect();
    _relay = null;
  }

  void _emit(AuthSession? session) {
    _current = session;
    _sessionCtrl.add(session);
    if (session != null) {
      unawaited(_watchSessionRevoked());
    } else {
      unawaited(_teardownRevokedWatch());
    }
  }
}
