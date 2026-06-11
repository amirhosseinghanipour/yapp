import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/messages/domain/repositories/messenger_repository.dart';
import '../../features/messages/presentation/screens/chat_detail_screen.dart';
import '../../features/messages/presentation/screens/contacts_screen.dart';
import '../../features/messages/presentation/yapp_design.dart';
import '../../features/profile/domain/entities/my_profile.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/widgets/profile_avatar.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/widgets/yapp_confirm_sheet.dart';
import '../di/app_scope.dart';
import '../theme/yapp_palette.dart';

class AppMenuDrawer extends StatefulWidget {
  const AppMenuDrawer({super.key});

  @override
  State<AppMenuDrawer> createState() => _AppMenuDrawerState();
}

class _AppMenuDrawerState extends State<AppMenuDrawer> {
  ProfileRepository? _profile;
  MessengerRepository? _messenger;
  AuthRepository? _auth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profile = AppScope.profileOf(context);
    _messenger = AppScope.of(context);
    _auth = AppScope.authOf(context);
  }

  void _open(Widget page) {
    Navigator.of(context).pop();
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _openSavedMessages() async {
    final repo = _messenger;
    if (repo == null) return;
    Navigator.of(context).pop();
    final saved = await repo.openSavedMessages();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(chatId: saved.id, peer: saved.user),
      ),
    );
  }

  void _toast(String msg) {
    final pal = YappPalette.of(context);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: pal.ink,
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final auth = _auth;
    if (auth == null) return;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    Navigator.of(context).pop();
    final ok = await showYappConfirmSheet(
      rootNavigator.context,
      headline: 'log out?',
      body:
          'you\'ll need your recovery phrase to sign in again on this device.',
      primaryLabel: 'log out',
      cancelLabel: 'stay',
      destructive: true,
    );
    if (ok != true) return;
    rootNavigator.popUntil((route) => route.isFirst);
    await auth.logout();
  }

  Future<void> _invite(MyProfile profile) async {
    final pal = YappPalette.of(context);
    Navigator.of(context).pop();
    final link = _profile!.shareLinkFor(profile);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'join me on yapp — $link',
          subject: 'join me on yapp',
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('invite link copied: $link'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: pal.ink,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final width = MediaQuery.sizeOf(context).width * 0.86;

    return Drawer(
      backgroundColor: pal.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pal.paper,
          border: Border(right: BorderSide(color: pal.ink, width: 1)),
        ),
        child: SafeArea(
          child: StreamBuilder<MyProfile>(
            stream: _profile?.watchProfile(),
            builder: (context, snap) {
              final me = snap.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (me != null)
                    _YappHeader(
                      profile: me,
                      repository: _profile,
                      onTap: () => _open(const ProfileScreen()),
                    ),
                  Container(height: 1, color: pal.ink),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      children: [
                        const _SectionLabel('you'),
                        _YappItem(
                          label: 'profile',
                          onTap: () => _open(const ProfileScreen()),
                        ),
                        _YappItem(
                          label: 'contacts',
                          onTap: () => _open(const ContactsScreen()),
                        ),
                        _YappItem(
                          label: 'settings',
                          onTap: () => _open(const SettingsScreen()),
                        ),
                        const SizedBox(height: 12),
                        const _SectionLabel('spaces'),
                        _YappItem(
                          label: 'saved messages',
                          onTap: _openSavedMessages,
                        ),
                        _YappItem(
                          label: 'invite friends',
                          onTap: me == null ? () {} : () => _invite(me),
                        ),
                        const SizedBox(height: 12),
                        const _SectionLabel('other'),
                        _YappItem(
                          label: 'help',
                          onTap: () => _toast('help center (demo).'),
                        ),
                        _YappItem(
                          label: 'log out',
                          danger: true,
                          onTap: _confirmLogout,
                        ),
                      ],
                    ),
                  ),
                  const _Footer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _YappHeader extends StatefulWidget {
  const _YappHeader({
    required this.profile,
    required this.repository,
    required this.onTap,
  });

  final MyProfile profile;
  final ProfileRepository? repository;
  final VoidCallback onTap;

  @override
  State<_YappHeader> createState() => _YappHeaderState();
}

class _YappHeaderState extends State<_YappHeader> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final p = widget.profile;
    final subtitle = [
      if (p.username != null) '@${p.username!.toLowerCase()}',
      if (p.phoneDisplay != null) p.phoneDisplay!.toLowerCase(),
    ].whereType<String>().join(' · ');

    final bg = _pressed ? pal.ink : pal.paper;
    final fg = _pressed ? pal.paper : pal.ink;
    final fgSub = _pressed ? pal.paper.withValues(alpha: 0.7) : pal.gray2;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        color: bg,
        padding: const EdgeInsets.fromLTRB(20, 22, 16, 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _SquareAvatar(
              profile: p,
              repository: widget.repository,
              onDark: _pressed,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.displayName.toLowerCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Yapp.name(color: fg).copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Yapp.label(color: fgSub),
                    ),
                  ],
                ],
              ),
            ),
            YappGlyph.forward(color: fg, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SquareAvatar extends StatelessWidget {
  const _SquareAvatar({
    required this.profile,
    required this.repository,
    required this.onDark,
  });

  final MyProfile profile;
  final ProfileRepository? repository;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final border = Border.all(color: onDark ? pal.paper : pal.ink, width: 1);
    if (!profile.hasAvatar || repository == null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: onDark ? pal.ink : pal.paper,
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          'y',
          style: TextStyle(
            color: onDark ? pal.paper : pal.ink,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1,
            fontFamily: Yapp.display().fontFamily,
          ),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(border: border),
      child: ProfileAvatar(profile: profile, repository: repository, size: 56),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Text(
        label,
        style: Yapp.label(
          color: pal.gray3,
        ).copyWith(fontWeight: FontWeight.w500, letterSpacing: 2, fontSize: 10),
      ),
    );
  }
}

class _YappItem extends StatefulWidget {
  const _YappItem({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_YappItem> createState() => _YappItemState();
}

class _YappItemState extends State<_YappItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final accent = widget.danger ? pal.alert : pal.ink;
    final bg = _pressed
        ? (widget.danger ? pal.alert.withValues(alpha: 0.06) : pal.pressWash)
        : pal.paper;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            left: BorderSide(
              color: _pressed ? accent : Colors.transparent,
              width: Yapp.tickWidth,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20 - Yapp.tickWidth, 0, 20, 0),
        height: 56,
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: Yapp.name(
                  color: accent,
                ).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: _pressed ? accent : pal.gray3,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pal.paper,
        border: Border(top: BorderSide(color: pal.gray4, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'yapp.',
            style: Yapp.display(
              color: pal.gray3,
            ).copyWith(fontSize: 24, height: 1),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'v0.1',
              style: Yapp.label(color: pal.gray3).copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
