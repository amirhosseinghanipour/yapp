import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/yapp_palette.dart';
import '../../messages/presentation/yapp_design.dart';
import '../domain/repositories/auth_repository.dart';

class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  final _phrase = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phrase.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.restoreFromMnemonic(_phrase.text);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
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

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final focused = _focus.hasFocus;

    return Scaffold(
      backgroundColor: pal.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.zero,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: YappGlyph.back()),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Text('restore', style: Yapp.display().copyWith(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text(
                    'enter your 12 recovery words, separated by spaces, in '
                    'order.',
                    style: Yapp.body(color: pal.gray2).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'recovery phrase',
                    style: Yapp.label(
                      color: pal.gray2,
                    ).copyWith(letterSpacing: 2, fontSize: 10),
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: Yapp.dur,
                    curve: Yapp.curve,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: focused ? pal.ink : pal.gray3,
                        width: focused ? 2 : Yapp.hairline,
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: TextField(
                      controller: _phrase,
                      focusNode: _focus,
                      maxLines: 4,
                      autocorrect: false,
                      enableSuggestions: false,
                      cursorColor: pal.ink,
                      cursorWidth: 2,
                      style: Yapp.name(
                        color: pal.ink,
                      ).copyWith(fontSize: 17, height: 1.5),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'word one  word two  word three  …',
                        hintStyle: Yapp.name(
                          color: pal.gray3,
                        ).copyWith(fontSize: 17, height: 1.5),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: Yapp.body(color: pal.alert)),
                  ],
                ],
              ),
            ),
            _RestoreStampBar(busy: _busy, onTap: _busy ? null : _restore),
          ],
        ),
      ),
    );
  }
}

class _RestoreStampBar extends StatefulWidget {
  const _RestoreStampBar({required this.onTap, required this.busy});

  final VoidCallback? onTap;
  final bool busy;

  @override
  State<_RestoreStampBar> createState() => _RestoreStampBarState();
}

class _RestoreStampBarState extends State<_RestoreStampBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final enabled = widget.onTap != null && !widget.busy;
    final bg = !enabled
        ? pal.ink
        : _pressed
        ? pal.alert
        : pal.ink;
    final fg = enabled ? pal.paper : pal.gray3;

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
      child: Container(
        color: bg,
        child: SafeArea(
          top: false,
          child: AnimatedContainer(
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('restore & sign in', style: Yapp.cta(color: fg)),
                        YappGlyph.forward(color: fg),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
