import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../core/theme/yapp_palette.dart';

class Yapp {
  Yapp._();

  static const Color ink = Color(0xFF0A0A0A);
  static const Color paper = Color(0xFFFFFFFF);

  static const Color gray1 = Color(0xFF0A0A0A);
  static const Color gray2 = Color(0xFF6B6B6B);
  static const Color gray3 = Color(0xFFB8B8B8);
  static const Color gray4 = Color(0xFFF2F2F2);

  static const Color alert = Color(0xFFFF3B30);

  static const double rNone = 0;
  static const double rPill = 999;

  static const Duration dur = Duration(milliseconds: 180);
  static const Curve curve = Curves.easeOutCubic;

  static TextStyle backChevron({Color? color}) =>
      display(color: color).copyWith(fontSize: 28, height: 1);

  static TextStyle display({Color? color}) => GoogleFonts.spaceGrotesk(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -1.2,
    color: color,
  );

  static TextStyle label({Color? color}) => GoogleFonts.spaceGrotesk(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.0,
    letterSpacing: 0,
    color: color ?? gray2,
  );

  static TextStyle body({Color? color}) => GoogleFonts.spaceGrotesk(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: color ?? gray2,
  );

  static TextStyle name({Color? color}) => GoogleFonts.spaceGrotesk(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.1,
    color: color,
  );

  static TextStyle cta({Color? color}) => GoogleFonts.spaceGrotesk(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0.1,
    color: color ?? paper,
  );

  static TextStyle bubble({Color? color}) => GoogleFonts.spaceGrotesk(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: -0.05,
    color: color,
  );

  static TextStyle meta({Color? color}) => GoogleFonts.spaceGrotesk(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.0,
    letterSpacing: 0,
    color: color ?? gray2,
  );

  static const Radius radius = Radius.zero;

  static const double bubbleMaxWidthFraction = 0.78;

  static const double bubbleBorderRadius = 0;

  static const Color bubbleMineBg = ink;

  static const Color bubbleTheirsBg = paper;

  static const Color bubbleTheirsBorder = ink;

  static const double bubbleTickSize = 6;

  static const double hairline = 1;

  static TextDirection? dirFor(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    return Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  static Widget bidi({
    required TextEditingController controller,
    required Widget Function(TextDirection? dir) builder,
  }) {
    return _BidiBuilder(controller: controller, builder: builder);
  }

  static const Color pressWash = Color(0x0A0A0A0A);
  static const double tickWidth = 2;
}

class YappGlyph {
  YappGlyph._();

  static Widget back({Color? color, double size = 26}) =>
      Icon(Icons.arrow_back_rounded, color: color, size: size);

  static Widget forward({Color? color, double size = 20}) =>
      Icon(Icons.arrow_forward_rounded, color: color, size: size);

  static Widget down({Color? color, double size = 20}) =>
      Icon(Icons.arrow_downward_rounded, color: color, size: size);

  static Widget close({Color? color, double size = 22}) =>
      Icon(Icons.close_rounded, color: color, size: size);
}

class YappQuietRow extends StatefulWidget {
  const YappQuietRow({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 16),
    this.showDivider = true,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsets padding;
  final bool showDivider;
  final bool enabled;

  @override
  State<YappQuietRow> createState() => _YappQuietRowState();
}

class _YappQuietRowState extends State<YappQuietRow> {
  bool _pressed = false;

  void _set(bool v) {
    if (!widget.enabled) return;
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final tappable = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: tappable ? (_) => _set(true) : null,
      onTapCancel: tappable ? () => _set(false) : null,
      onTapUp: tappable ? (_) => _set(false) : null,
      onTap: tappable ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        decoration: BoxDecoration(
          color: _pressed ? pal.pressWash : pal.paper,
          border: Border(
            left: BorderSide(
              color: _pressed ? pal.ink : Colors.transparent,
              width: Yapp.tickWidth,
            ),
            bottom: widget.showDivider
                ? BorderSide(color: pal.gray4, width: Yapp.hairline)
                : BorderSide.none,
          ),
        ),
        padding: widget.padding.copyWith(
          left: widget.padding.left - Yapp.tickWidth,
        ),
        child: widget.child,
      ),
    );
  }
}

class YappSectionLabel extends StatelessWidget {
  const YappSectionLabel(
    this.label, {
    super.key,
    this.topSpace = 28,
    this.trailing,
  });

  final String label;
  final double topSpace;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topSpace, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toLowerCase(),
              style: Yapp.label(
                color: YappPalette.of(context).gray2,
              ).copyWith(letterSpacing: 2, fontSize: 10),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class YappTicks {
  YappTicks._();
  static const String sending = '…';
  static const String sent = '.';
  static const String delivered = ':';
  static const String read = '::';
  static const String failed = '!';
}

class _BidiBuilder extends StatefulWidget {
  const _BidiBuilder({required this.controller, required this.builder});

  final TextEditingController controller;
  final Widget Function(TextDirection? dir) builder;

  @override
  State<_BidiBuilder> createState() => _BidiBuilderState();
}

class _BidiBuilderState extends State<_BidiBuilder> {
  TextDirection? _dir;

  @override
  void initState() {
    super.initState();
    _dir = Yapp.dirFor(widget.controller.text);
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _BidiBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _dir = Yapp.dirFor(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final next = Yapp.dirFor(widget.controller.text);
    if (next != _dir) {
      setState(() => _dir = next);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_dir);
}
