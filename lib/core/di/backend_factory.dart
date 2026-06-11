import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/repositories/auth_repository_supabase.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/messages/data/repositories/messenger_repository_supabase.dart';
import '../../features/profile/data/repositories/profile_repository_supabase.dart';
import '../../features/settings/data/repositories/settings_repository_supabase.dart';
import '../crypto/libsignal/libsignal_ratchet_engine.dart';
import '../graphql/token_storage.dart';
import '../supabase/auth_api.dart';
import '../supabase/realtime_relay.dart';
import '../supabase/supabase_config.dart';

class SessionRepos {
  SessionRepos({
    required this.messenger,
    required this.profile,
    required this.settings,
  });

  final MessengerRepositorySupabase messenger;
  final ProfileRepositorySupabase profile;
  final SettingsRepositorySupabase settings;
}

class SupabaseRuntime {
  SupabaseRuntime({
    required this.client,
    required this.auth,
    required this.tokens,
  });

  final SupabaseClient client;
  final AuthRepository auth;
  final TokenStorage tokens;

  static Future<SupabaseRuntime> bootstrap({
    String? supabaseUrl,
    String? anonKey,
    TokenStorage? tokenStorage,
  }) async {
    final url = supabaseUrl ?? kSupabaseUrl;
    final anon = anonKey ?? kSupabaseAnonKey;
    final tokens = tokenStorage ?? TokenStorage();
    final authApi = SupabaseAuthApi(supabaseUrl: url, anonKey: anon);

    final supabase = await Supabase.initialize(
      url: url,
      publishableKey: anon,
      accessToken: () => _freshAccessToken(tokens, authApi),
    );

    final auth = AuthRepositorySupabase(
      client: supabase.client,
      authApi: authApi,
      tokenStorage: tokens,
    );
    await auth.init();

    return SupabaseRuntime(client: supabase.client, auth: auth, tokens: tokens);
  }

  SessionRepos buildSession(AuthSession? session) {
    final accountId = session?.accountId ?? '';
    final deviceId = session?.deviceId ?? '';
    final settings = SettingsRepositorySupabase(
      client: client,
      accountId: accountId,
    );
    final relay = RealtimeRelay(client: client, accountId: accountId);
    final ratchet = LibsignalRatchetEngine(
      selfAccountId: accountId,
      client: client,
    );
    final messenger = MessengerRepositorySupabase(
      client: client,
      accountId: accountId,
      deviceId: deviceId,
      ratchet: ratchet,
      relay: relay,
      settings: settings,
    );
    final profile = ProfileRepositorySupabase(
      client: client,
      accountId: accountId,
    );
    return SessionRepos(
      messenger: messenger,
      profile: profile,
      settings: settings,
    );
  }

  static Future<String?> _freshAccessToken(
    TokenStorage tokens,
    SupabaseAuthApi authApi,
  ) async {
    final access = await tokens.readAccessToken();
    final exp = await tokens.readAccessExpiresAt();
    final needsRefresh =
        access == null ||
        exp == null ||
        DateTime.now().toUtc().isAfter(
          exp.toUtc().subtract(const Duration(seconds: 45)),
        );
    if (!needsRefresh) return access;

    final deviceId = await tokens.readDeviceId();
    final refreshToken = await tokens.readRefreshToken();
    if (deviceId == null || refreshToken == null) return access;
    try {
      final payload = await authApi.refresh(
        deviceId: deviceId,
        refreshToken: refreshToken,
      );
      await tokens.writeSession(
        accessToken: payload['accessToken'] as String,
        refreshToken: payload['refreshToken'] as String,
        deviceId: payload['deviceId'] as String,
        accountId: payload['accountId'] as String,
        accessExpiresAt: DateTime.parse(
          payload['accessTokenExpiresAt'] as String,
        ),
      );
      return payload['accessToken'] as String;
    } catch (_) {
      return access;
    }
  }
}
