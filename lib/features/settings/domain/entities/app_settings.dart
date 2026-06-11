import 'app_theme_mode.dart';
import 'blocked_user.dart';
import 'chat_wallpaper.dart';
import 'font_scale.dart';
import 'last_seen_visibility.dart';

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.autoDownloadMedia,
    required this.lastSeen,
    required this.blocked,
    required this.fontScale,
    required this.wallpaper,
    this.allowForwarding = true,
    this.sendReadReceipts = true,
  });

  final AppThemeMode themeMode;
  final bool autoDownloadMedia;
  final LastSeenVisibility lastSeen;
  final List<BlockedUser> blocked;
  final FontScale fontScale;
  final ChatWallpaper wallpaper;

  final bool allowForwarding;

  final bool sendReadReceipts;

  static const AppSettings defaults = AppSettings(
    themeMode: AppThemeMode.system,
    autoDownloadMedia: true,
    lastSeen: LastSeenVisibility.everyone,
    blocked: [],
    fontScale: FontScale.medium,
    wallpaper: ChatWallpaper.none,
    allowForwarding: true,
    sendReadReceipts: true,
  );

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? autoDownloadMedia,
    LastSeenVisibility? lastSeen,
    List<BlockedUser>? blocked,
    FontScale? fontScale,
    ChatWallpaper? wallpaper,
    bool? allowForwarding,
    bool? sendReadReceipts,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      autoDownloadMedia: autoDownloadMedia ?? this.autoDownloadMedia,
      lastSeen: lastSeen ?? this.lastSeen,
      blocked: blocked ?? this.blocked,
      fontScale: fontScale ?? this.fontScale,
      wallpaper: wallpaper ?? this.wallpaper,
      allowForwarding: allowForwarding ?? this.allowForwarding,
      sendReadReceipts: sendReadReceipts ?? this.sendReadReceipts,
    );
  }
}
