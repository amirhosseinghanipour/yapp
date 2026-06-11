import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/di/app_scope.dart';
import '../../../core/theme/yapp_palette.dart';
import '../../messages/presentation/screens/chat_detail_screen.dart';
import '../../messages/presentation/yapp_design.dart';
import '../domain/entities/my_profile.dart';
import '../domain/repositories/profile_repository.dart';
import 'edit_profile_screen.dart';
import 'profile_qr_screen.dart';
import 'widgets/avatar_source_sheet.dart';
import 'widgets/field_editor_sheet.dart';
import 'widgets/profile_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.repository});

  final ProfileRepository? repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileRepository? _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = widget.repository ?? AppScope.profileOf(context);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message.toLowerCase())));
  }

  Future<void> _editAll() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()));
  }

  Future<void> _pickAvatar(MyProfile profile) async {
    final repo = _repo;
    if (repo == null) return;
    final picked = await showAvatarSourceSheet(context, canRemove: true);
    if (picked == null) return;
    try {
      if (picked.result == AvatarSourceResult.picked && picked.path != null) {
        await repo.updateAvatar(picked.path!);
        if (mounted) _toast('profile photo updated');
      } else {
        await repo.removeAvatar();
        if (mounted) _toast('profile photo removed');
      }
    } catch (e) {
      if (mounted) _toast('could not update photo');
    }
  }

  Future<void> _share(MyProfile profile) async {
    final repo = _repo!;
    final link = repo.shareLinkFor(profile);
    try {
      final params = ShareParams(
        text: 'say hi to ${profile.displayName} on yapp: $link',
        subject: '${profile.displayName} on yapp',
      );
      await SharePlus.instance.share(params);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) _toast('link copied');
    }
  }

  Future<void> _showQr(MyProfile profile) async {
    final repo = _repo!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileQrScreen(
          profile: profile,
          shareLink: repo.shareLinkFor(profile),
        ),
      ),
    );
  }

  Future<void> _editName(MyProfile profile) async {
    final value = await showFieldEditorSheet(
      context,
      title: 'name',
      initialValue: profile.displayName,
      hint: 'your full name',
      maxLength: 60,
      allowEmpty: false,
    );
    if (value == null) return;
    await _repo!.updateProfile(displayName: value);
    if (mounted) _toast('name updated');
  }

  Future<void> _editUsername(MyProfile profile) async {
    final value = await showFieldEditorSheet(
      context,
      title: 'handle',
      initialValue: profile.username,
      hint: 'handle',
      prefix: '@',
      maxLength: 24,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\.]')),
      ],
      helper: 'letters, numbers, underscores, dots. empty to remove.',
      validator: (v) {
        if (v.isEmpty) return null;
        if (v.length < 3) return 'at least 3 characters';
        return null;
      },
    );
    if (value == null) return;
    await _repo!.updateProfile(
      username: value.isEmpty ? null : value,
      unsetUsername: value.isEmpty,
    );
    if (mounted) _toast('handle updated');
  }

  Future<void> _editBio(MyProfile profile) async {
    final value = await showFieldEditorSheet(
      context,
      title: 'bio',
      initialValue: profile.bio,
      hint: 'tell people about yourself',
      maxLength: 140,
      minLines: 2,
      maxLines: 4,
    );
    if (value == null) return;
    await _repo!.updateProfile(
      bio: value.isEmpty ? null : value,
      unsetBio: value.isEmpty,
    );
    if (mounted) _toast('bio updated');
  }

  Future<void> _invite(MyProfile profile) async {
    final link = _repo!.shareLinkFor(profile);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'join me on yapp — $link',
          subject: 'join me on yapp',
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      if (mounted) _toast('invite link copied');
    }
  }

  Future<void> _openSaved() async {
    final repo = AppScope.of(context);
    final summary = await repo.openSavedMessages();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatDetailScreen(chatId: summary.id, peer: summary.user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final repo = _repo;
    return Scaffold(
      backgroundColor: pal.paper,
      body: repo == null
          ? const SizedBox.shrink()
          : StreamBuilder<MyProfile>(
              stream: repo.watchProfile(),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                if (profile == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _ProfileBody(
                  profile: profile,
                  repository: repo,
                  onBack: () => Navigator.of(context).maybePop(),
                  onTapAvatar: () => _pickAvatar(profile),
                  onEdit: _editAll,
                  onShare: () => _share(profile),
                  onQr: () => _showQr(profile),
                  onEditName: () => _editName(profile),
                  onEditUsername: () => _editUsername(profile),
                  onEditBio: () => _editBio(profile),
                  onOpenSaved: _openSaved,
                  onInvite: () => _invite(profile),
                );
              },
            ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.repository,
    required this.onBack,
    required this.onTapAvatar,
    required this.onEdit,
    required this.onShare,
    required this.onQr,
    required this.onEditName,
    required this.onEditUsername,
    required this.onEditBio,
    required this.onOpenSaved,
    required this.onInvite,
  });

  final MyProfile profile;
  final ProfileRepository repository;
  final VoidCallback onBack;
  final VoidCallback onTapAvatar;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onQr;
  final VoidCallback onEditName;
  final VoidCallback onEditUsername;
  final VoidCallback onEditBio;
  final VoidCallback onOpenSaved;
  final VoidCallback onInvite;

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${label.toLowerCase()} copied')));
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final handle = profile.username != null ? '@${profile.username}' : null;
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _YappHeader(onBack: onBack)),
          SliverToBoxAdapter(
            child: _Hero(
              profile: profile,
              repository: repository,
              handle: handle,
              onTapAvatar: onTapAvatar,
            ),
          ),
          SliverToBoxAdapter(
            child: _StampStrip(onEdit: onEdit, onShare: onShare, onQr: onQr),
          ),
          const SliverToBoxAdapter(
            child: YappSectionLabel('account', topSpace: 24),
          ),
          SliverToBoxAdapter(
            child: _LinkRow(
              label: 'name',
              value: profile.displayName,
              onTap: onEditName,
              onLongPress: () => _copy(context, profile.displayName, 'name'),
            ),
          ),
          SliverToBoxAdapter(
            child: _LinkRow(
              label: 'handle',
              prefix: '@',
              value: profile.username ?? 'set one',
              muted: profile.username == null,
              onTap: onEditUsername,
              onLongPress: handle != null
                  ? () => _copy(context, handle, 'handle')
                  : null,
            ),
          ),
          SliverToBoxAdapter(
            child: _LinkRow(
              label: 'bio',
              value: profile.bio ?? 'add a short bio',
              muted: profile.bio == null,
              onTap: onEditBio,
              onLongPress: profile.bio != null
                  ? () => _copy(context, profile.bio!, 'bio')
                  : null,
            ),
          ),
          const SliverToBoxAdapter(
            child: YappSectionLabel('shortcuts', topSpace: 28),
          ),
          SliverToBoxAdapter(
            child: _LinkRow(
              label: 'saved messages',
              value: 'open  →',
              onTap: onOpenSaved,
            ),
          ),
          SliverToBoxAdapter(
            child: _LinkRow(label: 'my qr code', value: 'open  →', onTap: onQr),
          ),
          SliverToBoxAdapter(
            child: _LinkRow(
              label: 'invite friends',
              value: 'share  →',
              onTap: onInvite,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  'yapp',
                  style: Yapp.label(
                    color: pal.gray3,
                  ).copyWith(letterSpacing: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YappHeader extends StatelessWidget {
  const _YappHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      height: 72,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: YappGlyph.back(),
            ),
          ),
          const SizedBox(width: 10),
          Text('profile', style: Yapp.display().copyWith(fontSize: 24)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.profile,
    required this.repository,
    required this.handle,
    required this.onTapAvatar,
  });

  final MyProfile profile;
  final ProfileRepository repository;
  final String? handle;
  final VoidCallback onTapAvatar;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapAvatar,
                child: ProfileAvatar(
                  profile: profile,
                  repository: repository,
                  size: 96,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.displayName.toLowerCase(),
                      style: Yapp.display().copyWith(fontSize: 32, height: 1),
                    ),
                    if (handle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        handle!,
                        style: Yapp.body(
                          color: pal.gray2,
                        ).copyWith(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio != null) ...[
            const SizedBox(height: 18),
            Text(
              profile.bio!.toLowerCase(),
              style: Yapp.body(color: pal.ink).copyWith(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _StampStrip extends StatelessWidget {
  const _StampStrip({
    required this.onEdit,
    required this.onShare,
    required this.onQr,
  });

  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onQr;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: _QuietStripCell(label: 'edit', onTap: onEdit),
          ),
          Container(width: Yapp.hairline, color: pal.gray4),
          Expanded(
            child: _QuietStripCell(label: 'share', onTap: onShare),
          ),
          Container(width: Yapp.hairline, color: pal.gray4),
          Expanded(
            child: _QuietStripCell(label: 'qr', onTap: onQr),
          ),
        ],
      ),
    );
  }
}

class _QuietStripCell extends StatefulWidget {
  const _QuietStripCell({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuietStripCell> createState() => _QuietStripCellState();
}

class _QuietStripCellState extends State<_QuietStripCell> {
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
        height: 64,
        decoration: BoxDecoration(
          color: _pressed ? pal.pressWash : pal.paper,
          border: Border(
            left: BorderSide(
              color: _pressed ? pal.ink : Colors.transparent,
              width: Yapp.tickWidth,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Yapp.name(
            color: pal.ink,
          ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.onLongPress,
    this.muted = false,
    this.prefix,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool muted;

  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final valueColor = muted ? pal.gray3 : pal.ink;
    return YappQuietRow(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label.toLowerCase(),
            style: Yapp.body(color: pal.gray2).copyWith(fontSize: 14),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (prefix != null)
                  Text(
                    prefix!,
                    style: Yapp.name(color: pal.gray2).copyWith(fontSize: 15),
                  ),
                Flexible(
                  child: Text(
                    value.toLowerCase(),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Yapp.name(color: valueColor).copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
