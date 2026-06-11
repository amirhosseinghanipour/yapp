import '../entities/app_settings.dart';
import '../entities/app_theme_mode.dart';
import '../entities/blocked_user.dart';
import '../entities/chat_wallpaper.dart';
import '../entities/font_scale.dart';
import '../entities/last_seen_visibility.dart';

abstract class SettingsRepository {
  Future<AppSettings> load();
  Stream<AppSettings> watch();

  Future<void> setThemeMode(AppThemeMode mode);
  Future<void> setAutoDownloadMedia(bool enabled);

  Future<void> setAllowForwarding(bool enabled);

  Future<void> setSendReadReceipts(bool enabled);

  Future<void> setLastSeen(LastSeenVisibility value);

  Future<void> blockUser(BlockedUser user);
  Future<void> unblockUser(String id);
  bool isBlocked(String id);

  Future<void> setFontScale(FontScale value);
  Future<void> setWallpaper(ChatWallpaper value);

  Future<void> resetAll();
}
