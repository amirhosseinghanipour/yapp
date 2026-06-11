import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/yapp_palette.dart';
import '../../messages/presentation/yapp_design.dart';
import '../domain/repositories/auth_repository.dart';
import 'recovery_phrase_screen.dart';
import 'restore_screen.dart';
import 'scan_link_device_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _username = TextEditingController();
  final _usernameFocus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _username.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final words = await widget.repository.registerNewAccount(
        username: _username.text.trim().isEmpty ? null : _username.text.trim(),
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (routeContext) => RecoveryPhraseScreen(
            mnemonic: words,
            onConfirmed: () => Navigator.of(routeContext).pop(),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message ?? e.code.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  void _openRestore() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RestoreScreen(repository: widget.repository),
      ),
    );
  }

  void _openScan() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanLinkDeviceScreen(repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final focused = _usernameFocus.hasFocus;

    return Scaffold(
      backgroundColor: pal.paper,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                children: [
                  Text(
                    'yapp',
                    style: Yapp.display().copyWith(
                      fontSize: 72,
                      letterSpacing: -3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'encrypted by default.\nno phone number. no email. just you.',
                    style: Yapp.body(
                      color: pal.gray2,
                    ).copyWith(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 56),
                  Text(
                    'handle — optional',
                    style: Yapp.label(
                      color: pal.gray2,
                    ).copyWith(letterSpacing: 2, fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _username,
                    focusNode: _usernameFocus,
                    autocorrect: false,
                    enableSuggestions: false,
                    cursorColor: pal.ink,
                    cursorWidth: 2,
                    style: Yapp.name(color: pal.ink).copyWith(fontSize: 22),
                    onSubmitted: (_) => _busy ? null : _createAccount(),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.only(bottom: 8),
                      border: InputBorder.none,
                      hintText: 'pick a handle',
                      hintStyle: Yapp.name(
                        color: pal.gray3,
                      ).copyWith(fontSize: 22),
                    ),
                  ),
                  AnimatedContainer(
                    duration: Yapp.dur,
                    curve: Yapp.curve,
                    height: focused ? 2 : Yapp.hairline,
                    color: pal.ink,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: Yapp.body(color: pal.alert)),
                  ],
                ],
              ),
            ),
            _StampBar(
              label: 'create account',
              trailingIcon: Icons.arrow_forward_rounded,
              fill: pal.ink,
              textColor: pal.paper,
              pressFill: pal.alert,
              busy: _busy,
              onTap: _busy ? null : _createAccount,
            ),
            const _BarHairline(),
            _StampBar(
              label: 'restore with phrase',
              fill: pal.paper,
              textColor: pal.ink,
              onTap: _busy ? null : _openRestore,
            ),
            const _BarHairline(),
            _StampBar(
              label: 'link a device',
              fill: pal.paper,
              textColor: pal.ink,
              onTap: _busy ? null : _openScan,
              bottomSafeArea: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _StampBar extends StatefulWidget {
  const _StampBar({
    required this.label,
    required this.fill,
    required this.textColor,
    required this.onTap,
    this.trailingIcon,
    this.pressFill,
    this.busy = false,
    this.bottomSafeArea = false,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final VoidCallback? onTap;
  final IconData? trailingIcon;

  final Color? pressFill;
  final bool busy;
  final bool bottomSafeArea;

  @override
  State<_StampBar> createState() => _StampBarState();
}

class _StampBarState extends State<_StampBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final enabled = widget.onTap != null && !widget.busy;
    final disabled = !enabled;

    final Color bg;
    final Color fg;
    if (disabled) {
      bg = widget.fill;
      fg = pal.gray3;
    } else if (_pressed) {
      bg = widget.pressFill ?? widget.textColor;
      fg = widget.pressFill != null ? pal.paper : widget.fill;
    } else {
      bg = widget.fill;
      fg = widget.textColor;
    }

    final bar = AnimatedContainer(
      duration: Yapp.dur,
      curve: Yapp.curve,
      height: 64,
      color: bg,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: widget.busy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisAlignment: widget.trailingIcon != null
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                children: [
                  Text(widget.label, style: Yapp.cta(color: fg)),
                  if (widget.trailingIcon != null)
                    Icon(widget.trailingIcon, color: fg, size: 22),
                ],
              ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.mediumImpact();
              widget.onTap!();
            }
          : null,
      child: widget.bottomSafeArea
          ? Container(
              color: bg,
              child: SafeArea(top: false, child: bar),
            )
          : bar,
    );
  }
}

class _BarHairline extends StatelessWidget {
  const _BarHairline();

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return SizedBox(
      height: Yapp.hairline,
      child: ColoredBox(color: pal.ink),
    );
  }
}
