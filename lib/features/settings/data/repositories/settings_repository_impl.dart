import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/app_theme_mode.dart';
import '../../domain/entities/blocked_user.dart';
import '../../domain/entities/chat_wallpaper.dart';
import '../../domain/entities/font_scale.dart';
import '../../domain/entities/last_seen_visibility.dart';
import '../../domain/repositories/settings_repository.dart';

class _Keys {
  static const theme = 'settings.theme_mode';
  static const autoDownload = 'settings.auto_download_media';
  static const allowForwarding = 'settings.allow_forwarding';
  static const readReceipts = 'settings.send_read_receipts';
  static const lastSeen = 'settings.last_seen';
  static const blocked = 'settings.blocked_users_json';
  static const fontScale = 'settings.font_scale';
  static const wallpaper = 'settings.wallpaper';
}

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl();

  final StreamController<AppSettings> _controller =
      StreamController<AppSettings>.broadcast();

  SharedPreferences? _prefs;
  AppSettings? _cache;
  Future<AppSettings>? _loading;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<AppSettings> load() => _loading ??= _load();

  Future<AppSettings> _load() async {
    final prefs = await _ensurePrefs();

    final blockedRaw = prefs.getString(_Keys.blocked);
    List<BlockedUser> blocked = const [];
    if (blockedRaw != null && blockedRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(blockedRaw) as List<dynamic>;
        blocked = decoded
            .map(
              (e) => BlockedUser.fromJson(Map<String, Object?>.from(e as Map)),
            )
            .toList(growable: false);
      } catch (_) {
        blocked = const [];
      }
    }

    final settings = AppSettings(
      themeMode: AppThemeMode.fromStorage(prefs.getString(_Keys.theme)),
      autoDownloadMedia:
          prefs.getBool(_Keys.autoDownload) ??
          AppSettings.defaults.autoDownloadMedia,
      lastSeen: LastSeenVisibility.fromStorage(prefs.getString(_Keys.lastSeen)),
      blocked: blocked,
      fontScale: FontScale.fromStorage(prefs.getString(_Keys.fontScale)),
      wallpaper: ChatWallpaper.fromStorage(prefs.getString(_Keys.wallpaper)),
      allowForwarding:
          prefs.getBool(_Keys.allowForwarding) ??
          AppSettings.defaults.allowForwarding,
      sendReadReceipts:
          prefs.getBool(_Keys.readReceipts) ??
          AppSettings.defaults.sendReadReceipts,
    );
    _cache = settings;
    return settings;
  }

  @override
  Stream<AppSettings> watch() async* {
    yield await _current();
    yield* _controller.stream;
  }

  void _emit(AppSettings next) {
    _cache = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  Future<AppSettings> _current() async => _cache ?? await load();

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_Keys.theme, mode.storageValue);
    _emit((await _current()).copyWith(themeMode: mode));
  }

  @override
  Future<void> setAutoDownloadMedia(bool enabled) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_Keys.autoDownload, enabled);
    _emit((await _current()).copyWith(autoDownloadMedia: enabled));
  }

  @override
  Future<void> setAllowForwarding(bool enabled) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_Keys.allowForwarding, enabled);
    _emit((await _current()).copyWith(allowForwarding: enabled));
  }

  @override
  Future<void> setSendReadReceipts(bool enabled) async {
    final prefs = await _ensurePrefs();
    await prefs.setBool(_Keys.readReceipts, enabled);
    _emit((await _current()).copyWith(sendReadReceipts: enabled));
  }

  @override
  Future<void> setLastSeen(LastSeenVisibility value) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_Keys.lastSeen, value.storageValue);
    _emit((await _current()).copyWith(lastSeen: value));
  }

  @override
  Future<void> blockUser(BlockedUser user) async {
    final current = await _current();
    if (current.blocked.any((b) => b.id == user.id)) return;
    final next = [...current.blocked, user];
    await _persistBlocked(next);
    _emit(current.copyWith(blocked: next));
  }

  @override
  Future<void> unblockUser(String id) async {
    final current = await _current();
    final next = current.blocked.where((b) => b.id != id).toList();
    if (next.length == current.blocked.length) return;
    await _persistBlocked(next);
    _emit(current.copyWith(blocked: next));
  }

  Future<void> replaceBlockedFromServer(List<String> ids) async {
    final current = await _current();
    final nameById = {for (final b in current.blocked) b.id: b.name};
    final next = ids
        .map((id) => BlockedUser(id: id, name: nameById[id] ?? 'blocked user'))
        .toList(growable: false);
    await _persistBlocked(next);
    _emit(current.copyWith(blocked: next));
  }

  @override
  bool isBlocked(String id) {
    final snapshot = _cache;
    if (snapshot == null) return false;
    return snapshot.blocked.any((b) => b.id == id);
  }

  Future<void> _persistBlocked(List<BlockedUser> users) async {
    final prefs = await _ensurePrefs();
    final encoded = jsonEncode(users.map((u) => u.toJson()).toList());
    await prefs.setString(_Keys.blocked, encoded);
  }

  @override
  Future<void> setFontScale(FontScale value) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_Keys.fontScale, value.storageValue);
    _emit((await _current()).copyWith(fontScale: value));
  }

  @override
  Future<void> setWallpaper(ChatWallpaper value) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_Keys.wallpaper, value.storageValue);
    _emit((await _current()).copyWith(wallpaper: value));
  }

  @override
  Future<void> resetAll() async {
    final prefs = await _ensurePrefs();
    await Future.wait([
      prefs.remove(_Keys.theme),
      prefs.remove(_Keys.autoDownload),
      prefs.remove(_Keys.lastSeen),
      prefs.remove(_Keys.blocked),
      prefs.remove(_Keys.fontScale),
      prefs.remove(_Keys.wallpaper),
    ]);
    _emit(AppSettings.defaults);
  }
}
