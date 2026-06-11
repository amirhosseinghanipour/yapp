import 'token_storage.dart';

Future<void> persistAuthPayload(
  TokenStorage store,
  Map<String, dynamic> payload,
) async {
  await store.writeSession(
    accessToken: payload['accessToken'] as String,
    refreshToken: payload['refreshToken'] as String,
    deviceId: payload['deviceId'] as String,
    accountId: payload['accountId'] as String,
    accessExpiresAt: DateTime.parse(payload['accessTokenExpiresAt'] as String),
  );
}
