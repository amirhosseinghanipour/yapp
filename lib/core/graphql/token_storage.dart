import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'yapp.accessToken';
  static const _refreshKey = 'yapp.refreshToken';
  static const _deviceKey = 'yapp.deviceId';
  static const _accountKey = 'yapp.accountId';
  static const _expiresKey = 'yapp.accessExpiresAt';

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);
  Future<String?> readDeviceId() => _storage.read(key: _deviceKey);
  Future<String?> readAccountId() => _storage.read(key: _accountKey);

  Future<DateTime?> readAccessExpiresAt() async {
    final raw = await _storage.read(key: _expiresKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String deviceId,
    required String accountId,
    required DateTime accessExpiresAt,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _deviceKey, value: deviceId);
    await _storage.write(key: _accountKey, value: accountId);
    await _storage.write(
      key: _expiresKey,
      value: accessExpiresAt.toUtc().toIso8601String(),
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _deviceKey);
    await _storage.delete(key: _accountKey);
    await _storage.delete(key: _expiresKey);
  }
}
