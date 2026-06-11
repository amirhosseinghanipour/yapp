import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../features/auth/domain/repositories/auth_repository.dart';
import 'supabase_config.dart';

class SupabaseAuthApi {
  SupabaseAuthApi({
    http.Client? httpClient,
    String? supabaseUrl,
    String? anonKey,
  }) : _http = httpClient ?? http.Client(),
       _endpoint = Uri.parse(
         '${supabaseUrl ?? kSupabaseUrl}/functions/v1/auth',
       ),
       _anonKey = anonKey ?? kSupabaseAnonKey;

  final http.Client _http;
  final Uri _endpoint;
  final String _anonKey;

  Future<Map<String, dynamic>> beginRegistration() =>
      _post('begin-registration', <String, dynamic>{});

  Future<Map<String, dynamic>> finishRegistration({
    required String challengeId,
    required String identityPublicKey,
    required String identitySignature,
    String? username,
    required String devicePublicKey,
    required String deviceName,
    required String platform,
    int? registrationId,
  }) => _post('finish-registration', <String, dynamic>{
    'challengeId': challengeId,
    'identityPublicKey': identityPublicKey,
    'identitySignature': identitySignature,
    'username': ?username,
    'devicePublicKey': devicePublicKey,
    'deviceName': deviceName,
    'platform': platform,
    'registrationId': ?registrationId,
  });

  Future<Map<String, dynamic>> beginRecovery({
    required String identityPublicKey,
  }) => _post('begin-recovery', <String, dynamic>{
    'identityPublicKey': identityPublicKey,
  });

  Future<Map<String, dynamic>> finishRecovery({
    required String challengeId,
    required String accountId,
    required String identitySignature,
    required String devicePublicKey,
    required String deviceName,
    required String platform,
    int? registrationId,
  }) => _post('finish-recovery', <String, dynamic>{
    'challengeId': challengeId,
    'accountId': accountId,
    'identitySignature': identitySignature,
    'devicePublicKey': devicePublicKey,
    'deviceName': deviceName,
    'platform': platform,
    'registrationId': ?registrationId,
  });

  Future<Map<String, dynamic>> beginAuth({required String deviceId}) =>
      _post('begin-auth', <String, dynamic>{'deviceId': deviceId});

  Future<Map<String, dynamic>> finishAuth({
    required String challengeId,
    required String deviceId,
    required String identitySignature,
  }) => _post('finish-auth', <String, dynamic>{
    'challengeId': challengeId,
    'deviceId': deviceId,
    'identitySignature': identitySignature,
  });

  Future<Map<String, dynamic>> finishLinkDevice({
    required String challengeId,
    required String accountId,
    required String identitySignature,
    required String devicePublicKey,
    required String deviceName,
    required String platform,
    int? registrationId,
  }) => _post('finish-link-device', <String, dynamic>{
    'challengeId': challengeId,
    'accountId': accountId,
    'identitySignature': identitySignature,
    'devicePublicKey': devicePublicKey,
    'deviceName': deviceName,
    'platform': platform,
    'registrationId': ?registrationId,
  });

  Future<Map<String, dynamic>> refresh({
    required String deviceId,
    required String refreshToken,
  }) => _post('refresh', <String, dynamic>{
    'deviceId': deviceId,
    'refreshToken': refreshToken,
  });

  Future<Map<String, dynamic>> beginLinkDevice({required String accessToken}) =>
      _post('begin-link-device', <String, dynamic>{}, accessToken: accessToken);

  Future<Map<String, dynamic>> logout({
    required String accessToken,
    required String deviceId,
  }) => _post('logout', <String, dynamic>{
    'deviceId': deviceId,
  }, accessToken: accessToken);

  Future<Map<String, dynamic>> _post(
    String action,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    http.Response response;
    try {
      response = await _http.post(
        _endpoint,
        headers: <String, String>{
          'apikey': _anonKey,
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(<String, dynamic>{'action': action, ...body}),
      );
    } on SocketException catch (e) {
      throw AuthException(AuthErrorCode.network, e.message);
    } on http.ClientException catch (e) {
      throw AuthException(AuthErrorCode.network, e.message);
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AuthException(
        AuthErrorCode.unknown,
        'Malformed response (${response.statusCode})',
      );
    }

    final error = json['error'];
    if (error is String) {
      throw AuthException(_mapCode(error), error);
    }
    if (response.statusCode >= 400) {
      throw AuthException(AuthErrorCode.unknown, 'HTTP ${response.statusCode}');
    }
    return json;
  }

  AuthErrorCode _mapCode(String raw) {
    switch (raw) {
      case 'invalidKey':
        return AuthErrorCode.invalidKey;
      case 'invalidSignature':
        return AuthErrorCode.invalidSignature;
      case 'invalidUsername':
        return AuthErrorCode.invalidUsername;
      case 'usernameTaken':
        return AuthErrorCode.usernameTaken;
      case 'challengeExpired':
        return AuthErrorCode.challengeExpired;
      case 'unknownHandle':
        return AuthErrorCode.unknownHandle;
      case 'rateLimited':
        return AuthErrorCode.rateLimited;
      case 'unauthenticated':
        return AuthErrorCode.unknown;
      default:
        return AuthErrorCode.unknown;
    }
  }

  void dispose() => _http.close();
}
