import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/yapp_palette.dart';
import '../../messages/presentation/yapp_design.dart';
import '../domain/entities/my_profile.dart';
import 'widgets/profile_avatar.dart';

class ProfileQrScreen extends StatelessWidget {
  const ProfileQrScreen({
    super.key,
    required this.profile,
    required this.shareLink,
  });

  final MyProfile profile;
  final String shareLink;

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message.toLowerCase())));
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareLink));
    if (!context.mounted) return;
    _toast(context, 'link copied');
  }

  Future<void> _share(BuildContext context) async {
    try {
      final params = ShareParams(
        text: 'say hi to ${profile.displayName} on yapp: $shareLink',
        subject: '${profile.displayName} on yapp',
      );
      await SharePlus.instance.share(params);
    } catch (_) {
      if (!context.mounted) return;
      _toast(context, 'sharing unavailable');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final handle = profile.username != null ? '@${profile.username}' : null;

    return Scaffold(
      backgroundColor: pal.paper,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProfileAvatar(source: profile.avatarUrl, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        profile.displayName.toLowerCase(),
                        style: Yapp.display().copyWith(fontSize: 28),
                        textAlign: TextAlign.center,
                      ),
                      if (handle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          handle,
                          style: Yapp.body(
                            color: pal.gray2,
                          ).copyWith(fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFFFF),
                          border: Border.all(
                            color: pal.ink,
                            width: Yapp.hairline,
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: QrImageView(
                          data: profile.username != null
                              ? 'yapp:user:${profile.username!.toLowerCase()}'
                              : shareLink,
                          version: QrVersions.auto,
                          size: 240,
                          gapless: true,
                          backgroundColor: const Color(0xFFFFFFFF),
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF0A0A0A),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF0A0A0A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'scan to yap',
                        style: Yapp.label(
                          color: pal.gray2,
                        ).copyWith(letterSpacing: 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _LinkStrip(link: shareLink, onCopy: () => _copy(context)),
            _StampStrip(
              onCopy: () => _copy(context),
              onShare: () => _share(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      height: 72,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
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
          Text('qr code', style: Yapp.display().copyWith(fontSize: 24)),
        ],
      ),
    );
  }
}

class _LinkStrip extends StatelessWidget {
  const _LinkStrip({required this.link, required this.onCopy});
  final String link;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: pal.ink, width: Yapp.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Yapp.body(color: pal.ink).copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StampStrip extends StatelessWidget {
  const _StampStrip({required this.onCopy, required this.onShare});
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: _StampCell(label: 'copy', onTap: onCopy, primary: false),
          ),
          Container(width: Yapp.hairline, color: pal.ink),
          Expanded(
            child: _StampCell(label: 'share  →', onTap: onShare, primary: true),
          ),
        ],
      ),
    );
  }
}

class _StampCell extends StatefulWidget {
  const _StampCell({
    required this.label,
    required this.onTap,
    required this.primary,
  });
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_StampCell> createState() => _StampCellState();
}

class _StampCellState extends State<_StampCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final baseFill = widget.primary ? pal.ink : pal.paper;
    final baseFg = widget.primary ? pal.paper : pal.ink;
    final fill = _pressed ? baseFg : baseFill;
    final fg = _pressed ? baseFill : baseFg;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        decoration: BoxDecoration(
          color: fill,
          border: Border(
            top: BorderSide(color: pal.ink, width: Yapp.hairline),
          ),
        ),
        alignment: Alignment.center,
        child: Text(widget.label, style: Yapp.cta(color: fg)),
      ),
    );
  }
}
