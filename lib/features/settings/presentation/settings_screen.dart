import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/di/app_scope.dart';
import '../../../core/theme/yapp_palette.dart';
import '../../messages/presentation/yapp_design.dart';
import '../../profile/domain/entities/my_profile.dart';
import '../../profile/domain/repositories/profile_repository.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/services/storage_service.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/app_theme_mode.dart';
import '../domain/entities/chat_wallpaper.dart';
import '../domain/entities/font_scale.dart';
import '../domain/entities/last_seen_visibility.dart';
import '../domain/repositories/settings_repository.dart';
import 'blocked_users_screen.dart';
import 'info_screens.dart';
import 'linked_devices_screen.dart';
import 'widgets/font_scale_sheet.dart';
import 'widgets/last_seen_sheet.dart';
import 'widgets/wallpaper_sheet.dart';
import 'widgets/yapp_confirm_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ProfileRepository? _profile;
  SettingsRepository? _settings;
  Stream<AppSettings>? _settingsStream;
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _query = '';
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (!mounted) return;
          setState(() => _packageInfo = info);
        })
        .catchError((_) {});
    _storage.measure().then((_) {
      if (!mounted) return;
      setState(() {});
    });
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profile = AppScope.profileOf(context);
    final settings = AppScope.settingsOf(context);
    if (!identical(settings, _settings)) {
      _settings = settings;
      _settingsStream = settings.watch();
    }
  }

  void _openProfile() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
  }

  void _openBlocked() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const BlockedUsersScreen()));
  }

  Future<void> _changeTheme(AppThemeMode mode) async {
    await _settings?.setThemeMode(mode);
  }

  Future<void> _pickLastSeen(LastSeenVisibility current) async {
    final picked = await showLastSeenSheet(context, current: current);
    if (picked == null) return;
    await _settings?.setLastSeen(picked);
  }

  Future<void> _pickWallpaper(ChatWallpaper current) async {
    final picked = await showWallpaperSheet(context, current: current);
    if (picked == null) return;
    await _settings?.setWallpaper(picked);
  }

  Future<void> _pickFontScale(FontScale current) async {
    final picked = await showFontScaleSheet(context, current: current);
    if (picked == null) return;
    await _settings?.setFontScale(picked);
  }

  Future<void> _openStorage() async {
    await _storage.measure();
    if (!mounted) return;
    setState(() {});
    final paper = YappPalette.of(context).paper;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => _YappStorageSheet(storage: _storage),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _confirmLogOut() async {
    final ok = await showYappConfirmSheet(
      context,
      headline: 'log out?',
      body:
          'your server preferences will be reset to defaults, then you will be signed out.',
      primaryLabel: 'log out',
      destructive: true,
    );
    if (ok != true) return;
    if (!mounted) return;
    final auth = AppScope.authOf(context);
    try {
      await _settings?.resetAll();
      await auth.logout();
    } catch (e) {
      if (!mounted) return;
      _toast('could not complete sign out. try again.');
      return;
    }
    if (!mounted) return;
    _toast('signed out.');
  }

  void _toast(String msg) {
    final pal = YappPalette.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: Yapp.cta(color: pal.paper)),
          backgroundColor: pal.ink,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Scaffold(
      backgroundColor: pal.paper,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<AppSettings>(
          stream: _settingsStream,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final settings = snap.data!;
            return StreamBuilder<MyProfile>(
              stream: _profile?.watchProfile(),
              builder: (context, profSnap) {
                final me = profSnap.data;
                final groups = _buildGroups(settings);
                final filtered = _filterGroups(groups, _query);

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _YappHeader()),
                    SliverToBoxAdapter(
                      child: _YappSearchField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: (v) => setState(() => _query = v.trim()),
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ),
                    if (me != null && _query.isEmpty)
                      SliverToBoxAdapter(
                        child: _MeStrip(profile: me, onTap: _openProfile),
                      ),
                    if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'nothing matches.',
                                style: Yapp.display().copyWith(
                                  fontSize: 28,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'try a different word.',
                                style: Yapp.body(color: pal.gray2),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList.list(
                        children: [
                          for (final g in filtered) ...[
                            _SectionLabel(label: g.title),
                            for (final row in g.children) row,
                          ],
                          if (_query.isEmpty) ...[
                            const SizedBox(height: 48),
                            _DangerRow(label: 'log out', onTap: _confirmLogOut),
                            const SizedBox(height: 32),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              child: Text(
                                _packageInfo == null
                                    ? 'yapp'
                                    : 'yapp · v${_packageInfo!.version} '
                                          '(${_packageInfo!.buildNumber})',
                                style: Yapp.label(color: pal.gray3),
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<_SettingsGroup> _buildGroups(AppSettings settings) {
    final storageUsage = _storage.lastMeasurement;

    return [
      _SettingsGroup(
        title: 'appearance',
        keywords: [
          'theme',
          'light',
          'dark',
          'auto',
          'appearance',
          'app color',
          'color',
          'background',
          'wallpaper',
          'text size',
          'font',
        ],
        children: [
          _SegmentRow<AppThemeMode>(
            label: 'theme',
            value: settings.themeMode,
            segments: const [
              _Segment(value: AppThemeMode.light, label: 'light'),
              _Segment(value: AppThemeMode.dark, label: 'dark'),
              _Segment(value: AppThemeMode.system, label: 'auto'),
            ],
            onChanged: _changeTheme,
          ),
          _LinkRow(
            label: 'app color',
            value: settings.wallpaper.label.toLowerCase(),
            onTap: () => _pickWallpaper(settings.wallpaper),
          ),
          _LinkRow(
            label: 'text size',
            value: settings.fontScale.label.toLowerCase(),
            onTap: () => _pickFontScale(settings.fontScale),
          ),
        ],
      ),
      _SettingsGroup(
        title: 'privacy',
        keywords: [
          'privacy',
          'last seen',
          'blocked',
          'block',
          'online status',
          'logout',
          'forward',
          'forwarding',
          'read receipts',
          'receipts',
        ],
        children: [
          _LinkRow(
            label: 'last seen',
            value: settings.lastSeen.label.toLowerCase(),
            onTap: () => _pickLastSeen(settings.lastSeen),
          ),
          _SwitchRow(
            label: 'allow forwarding',
            subtitle: 'let people forward messages you send',
            value: settings.allowForwarding,
            onChanged: (v) => _settings?.setAllowForwarding(v),
          ),
          _SwitchRow(
            label: 'read receipts',
            subtitle: 'show others when you’ve read their messages',
            value: settings.sendReadReceipts,
            onChanged: (v) => _settings?.setSendReadReceipts(v),
          ),
          _LinkRow(
            label: 'blocked',
            value: '${settings.blocked.length}',
            onTap: _openBlocked,
          ),
          _LinkRow(
            label: 'linked devices',
            chevron: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LinkedDevicesScreen(),
              ),
            ),
          ),
        ],
      ),
      _SettingsGroup(
        title: 'data',
        keywords: ['data', 'storage', 'cache', 'clear', 'download', 'media'],
        children: [
          _SwitchRow(
            label: 'auto-download media',
            subtitle:
                'load photos and files as they arrive. off = tap to download',
            value: settings.autoDownloadMedia,
            onChanged: (v) => _settings?.setAutoDownloadMedia(v),
          ),
          _LinkRow(
            label: 'storage',
            value: storageUsage == null
                ? 'measuring'
                : formatBytes(storageUsage.totalBytes).toLowerCase(),
            onTap: _openStorage,
          ),
        ],
      ),
      _SettingsGroup(
        title: 'about',
        keywords: ['about', 'terms', 'version'],
        children: [
          _LinkRow(
            label: 'terms',
            chevron: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TermsScreen()),
            ),
          ),
          _LinkRow(
            label: 'version',
            value: _packageInfo == null
                ? '…'
                : '${_packageInfo!.version} (${_packageInfo!.buildNumber})',
            onTap: null,
          ),
        ],
      ),
    ];
  }

  List<_SettingsGroup> _filterGroups(
    List<_SettingsGroup> groups,
    String query,
  ) {
    if (query.isEmpty) return groups;
    final needle = query.toLowerCase();
    return groups
        .where(
          (g) =>
              g.title.toLowerCase().contains(needle) ||
              g.keywords.any((k) => k.toLowerCase().contains(needle)),
        )
        .toList(growable: false);
  }
}

class _SettingsGroup {
  const _SettingsGroup({
    required this.title,
    required this.children,
    required this.keywords,
  });

  final String title;
  final List<Widget> children;
  final List<String> keywords;
}

class _YappHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: pal.paper,
        border: Border(
          bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: YappGlyph.back(),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'settings',
            style: Yapp.display().copyWith(fontSize: 28, height: 1.05),
          ),
        ],
      ),
    );
  }
}

class _YappSearchField extends StatelessWidget {
  const _YappSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final focused = focusNode.hasFocus;
    final underlineColor = focused ? pal.ink : pal.gray3;
    final underlineWidth = focused ? 2.0 : Yapp.hairline;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: Yapp.dur,
              curve: Yapp.curve,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: underlineColor,
                    width: underlineWidth,
                  ),
                ),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                cursorColor: pal.ink,
                style: Yapp.name(),
                decoration: InputDecoration(
                  hintText: 'find a setting',
                  hintStyle: Yapp.name(color: pal.gray3),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'clear',
                  style: Yapp.cta(color: pal.gray2).copyWith(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MeStrip extends StatefulWidget {
  const _MeStrip({required this.profile, required this.onTap});

  final MyProfile profile;
  final VoidCallback onTap;

  @override
  State<_MeStrip> createState() => _MeStripState();
}

class _MeStripState extends State<_MeStrip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final bg = _pressed ? pal.ink : pal.paper;
    final fg = _pressed ? pal.paper : pal.ink;
    final subFg = _pressed ? pal.gray3 : pal.gray2;

    final p = widget.profile;
    final subtitle = [
      if (p.username != null) '@${p.username}',
      if (p.phoneDisplay != null) p.phoneDisplay,
    ].whereType<String>().join(' · ').toLowerCase();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        color: bg,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            _SquareAvatar(
              imageUrl: p.avatarUrl,
              inverted: _pressed,
              initial: _firstLetter(p.displayName),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.displayName.toLowerCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Yapp.name(color: fg).copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Yapp.label(color: subFg),
                    ),
                  ],
                ],
              ),
            ),
            YappGlyph.forward(color: fg, size: 22),
          ],
        ),
      ),
    );
  }

  String _firstLetter(String name) {
    final t = name.trim();
    return t.isEmpty ? 'y' : t.characters.first.toLowerCase();
  }
}

class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({
    required this.imageUrl,
    required this.inverted,
    required this.initial,
  });

  final String? imageUrl;
  final bool inverted;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final fill = inverted ? pal.paper : pal.ink;
    final glyph = inverted ? pal.ink : pal.paper;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: inverted ? pal.paper : pal.ink, width: 1),
          image: DecorationImage(
            image: NetworkImage(imageUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      color: fill,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: glyph,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return YappSectionLabel(label, topSpace: 36);
  }
}

class _RowFrame extends StatefulWidget {
  const _RowFrame({required this.child, required this.onTap});

  final Widget Function(bool pressed) child;
  final VoidCallback? onTap;

  @override
  State<_RowFrame> createState() => _RowFrameState();
}

class _RowFrameState extends State<_RowFrame> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final tappable = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: tappable ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: tappable ? () => setState(() => _pressed = false) : null,
      onTapUp: tappable ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.fromLTRB(20 - Yapp.tickWidth, 14, 20, 14),
        decoration: BoxDecoration(
          color: _pressed ? pal.pressWash : pal.paper,
          border: Border(
            left: BorderSide(
              color: _pressed ? pal.ink : Colors.transparent,
              width: Yapp.tickWidth,
            ),
            bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
          ),
        ),
        child: widget.child(false),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    this.value,
    this.chevron = false,
    required this.onTap,
  });

  final String label;
  final String? value;

  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return _RowFrame(
      onTap: onTap,
      child: (pressed) {
        final fg = pressed ? pal.paper : pal.ink;
        final sub = pressed ? pal.gray3 : pal.gray2;
        return Row(
          children: [
            Expanded(
              child: Text(label.toLowerCase(), style: Yapp.name(color: fg)),
            ),
            if (chevron)
              YappGlyph.forward(color: onTap == null ? sub : fg, size: 18)
            else if (value != null)
              Flexible(
                child: Text(
                  value!.toLowerCase(),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: Yapp.name(color: onTap == null ? sub : fg).copyWith(
                    fontWeight: onTap == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return _RowFrame(
      onTap: () => onChanged(!value),
      child: (pressed) {
        final fg = pressed ? pal.paper : pal.ink;
        final sub = pressed ? pal.gray3 : pal.gray2;
        final stateColor = pressed ? pal.paper : (value ? pal.ink : pal.gray3);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label.toLowerCase(), style: Yapp.name(color: fg)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!.toLowerCase(),
                      style: Yapp.body(color: sub).copyWith(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: Yapp.dur,
              switchInCurve: Yapp.curve,
              child: Text(
                value ? 'on' : 'off',
                key: ValueKey<bool>(value),
                style: Yapp.name(color: stateColor).copyWith(
                  fontWeight: value ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Segment<T> {
  const _Segment({required this.value, required this.label});

  final T value;
  final String label;
}

class _SegmentRow<T> extends StatelessWidget {
  const _SegmentRow({
    required this.label,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<_Segment<T>> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return _RowFrame(
      onTap: null,
      child: (_) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label.toLowerCase(), style: Yapp.name()),
            const Spacer(),
            for (int i = 0; i < segments.length; i++) ...[
              if (i != 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('·', style: Yapp.name(color: pal.gray3)),
                ),
              _SegmentWord<T>(
                label: segments[i].label,
                selected: segments[i].value == value,
                onTap: () => onChanged(segments[i].value),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SegmentWord<T> extends StatelessWidget {
  const _SegmentWord({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? pal.ink : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label.toLowerCase(),
          style: Yapp.name(
            color: selected ? pal.ink : pal.gray2,
          ).copyWith(fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
        ),
      ),
    );
  }
}

class _DangerRow extends StatefulWidget {
  const _DangerRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_DangerRow> createState() => _DangerRowState();
}

class _DangerRowState extends State<_DangerRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          color: _pressed ? pal.alert.withValues(alpha: 0.06) : pal.paper,
          border: Border(
            left: BorderSide(
              color: _pressed ? pal.alert : Colors.transparent,
              width: Yapp.tickWidth,
            ),
            bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20 - Yapp.tickWidth, 14, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label.toLowerCase(),
                style: Yapp.name(
                  color: pal.alert,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            YappGlyph.forward(color: pal.alert, size: 18),
          ],
        ),
      ),
    );
  }
}

class _YappStorageSheet extends StatefulWidget {
  const _YappStorageSheet({required this.storage});
  final StorageService storage;

  @override
  State<_YappStorageSheet> createState() => _YappStorageSheetState();
}

class _YappStorageSheetState extends State<_YappStorageSheet> {
  StorageUsage? _usage;
  bool _clearing = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final u = await widget.storage.measure();
    if (!mounted) return;
    setState(() => _usage = u);
  }

  Future<void> _clear() async {
    setState(() => _clearing = true);
    final freed = await widget.storage.clearCache();
    if (!mounted) return;
    setState(() => _clearing = false);
    await _refresh();
    if (!mounted) return;
    final pal = YappPalette.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'freed ${formatBytes(freed).toLowerCase()} of cache.',
            style: Yapp.cta(color: pal.paper),
          ),
          backgroundColor: pal.ink,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final usage = _usage;
    final clearable = usage != null && usage.cacheBytes > 0 && !_clearing;
    final segments = usage == null
        ? const <_StorageSegment>[]
        : <_StorageSegment>[
            if (usage.cacheBytes > 0)
              _StorageSegment(
                label: 'cache',
                bytes: usage.cacheBytes,
                color: pal.ink,
              ),
            if (usage.documentsBytes > 0)
              _StorageSegment(
                label: 'documents',
                bytes: usage.documentsBytes,
                color: pal.gray3,
              ),
          ];

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'storage',
                  style: Yapp.display().copyWith(fontSize: 28, height: 1.05),
                ),
                const SizedBox(height: 6),
                Text(
                  usage == null
                      ? 'measuring…'
                      : '${formatBytes(usage.totalBytes).toLowerCase()} used by yapp',
                  style: Yapp.body(color: pal.gray2),
                ),
                const SizedBox(height: 20),
                if (usage != null && usage.totalBytes == 0)
                  Text(
                    'no app data on disk yet.',
                    style: Yapp.body(color: pal.gray2),
                  )
                else if (segments.isNotEmpty)
                  _YappStorageBar(segments: segments),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: clearable
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapCancel: clearable
                ? () => setState(() => _pressed = false)
                : null,
            onTapUp: clearable ? (_) => setState(() => _pressed = false) : null,
            onTap: clearable ? _clear : null,
            child: AnimatedContainer(
              duration: Yapp.dur,
              curve: Yapp.curve,
              height: 56,
              decoration: BoxDecoration(
                color: !clearable
                    ? pal.gray4
                    : (_pressed ? pal.paper : pal.ink),
                border: Border(
                  top: BorderSide(color: pal.ink, width: Yapp.hairline),
                ),
              ),
              alignment: Alignment.center,
              child: _clearing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: pal.paper,
                      ),
                    )
                  : Text(
                      clearable ? 'clear cache  →' : 'nothing to clear',
                      style: Yapp.cta(
                        color: !clearable
                            ? pal.gray2
                            : (_pressed ? pal.ink : pal.paper),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageSegment {
  const _StorageSegment({
    required this.label,
    required this.bytes,
    required this.color,
  });

  final String label;
  final int bytes;
  final Color color;
}

class _YappStorageBar extends StatelessWidget {
  const _YappStorageBar({required this.segments});
  final List<_StorageSegment> segments;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final total = segments.fold<int>(0, (a, s) => a + s.bytes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 12,
          decoration: Border.all(
            color: pal.ink,
            width: Yapp.hairline,
          ).toBoxDecoration(),
          child: Row(
            children: [
              for (int i = 0; i < segments.length; i++) ...[
                if (i != 0) Container(width: Yapp.hairline, color: pal.ink),
                Expanded(
                  flex: segments[i].bytes,
                  child: Container(color: segments[i].color),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final s in segments) ...[
          Row(
            children: [
              Container(width: 10, height: 10, color: s.color),
              const SizedBox(width: 10),
              Expanded(child: Text(s.label, style: Yapp.name())),
              Text(
                formatBytes(s.bytes).toLowerCase(),
                style: Yapp.label(color: pal.gray2),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Text(
          '${formatBytes(total).toLowerCase()} used',
          style: Yapp.label(color: pal.gray2),
        ),
      ],
    );
  }
}

extension on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}
