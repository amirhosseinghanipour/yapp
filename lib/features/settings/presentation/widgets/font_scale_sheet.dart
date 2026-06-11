import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../../messages/presentation/yapp_design.dart';
import '../../domain/entities/font_scale.dart';

Future<FontScale?> showFontScaleSheet(
  BuildContext context, {
  required FontScale current,
}) {
  return showModalBottomSheet<FontScale>(
    context: context,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => _FontScaleSheet(current: current),
  );
}

class _FontScaleSheet extends StatefulWidget {
  const _FontScaleSheet({required this.current});
  final FontScale current;

  @override
  State<_FontScaleSheet> createState() => _FontScaleSheetState();
}

class _FontScaleSheetState extends State<_FontScaleSheet> {
  late FontScale _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
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
                  'text size',
                  style: Yapp.display().copyWith(fontSize: 28, height: 1.05),
                ),
                const SizedBox(height: 6),
                Text(
                  'applies everywhere in yapp.',
                  style: Yapp.body(color: pal.gray2),
                ),
                const SizedBox(height: 20),
                _Preview(scale: _selected.multiplier),
              ],
            ),
          ),
          for (final v in FontScale.values)
            _FontRow(
              scale: v,
              selected: v == _selected,
              onTap: () {
                setState(() => _selected = v);
                Navigator.of(context).pop(v);
              },
            ),
          Container(height: Yapp.hairline, color: pal.ink),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreviewBlock(text: 'sample message at this size.', outgoing: false),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: _PreviewBlock(text: 'looks good?', outgoing: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({required this.text, required this.outgoing});
  final String text;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final fg = outgoing ? pal.paper : pal.ink;
    final bg = outgoing ? pal.ink : pal.paper;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: outgoing
            ? null
            : Border.all(color: pal.ink, width: Yapp.hairline),
      ),
      child: Text(text, style: Yapp.bubble(color: fg)),
    );
  }
}

class _FontRow extends StatefulWidget {
  const _FontRow({
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  final FontScale scale;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FontRow> createState() => _FontRowState();
}

class _FontRowState extends State<_FontRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final bg = _pressed ? pal.ink : pal.paper;
    final fg = _pressed ? pal.paper : pal.ink;
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(color: pal.ink, width: Yapp.hairline),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                'aa',
                style: TextStyle(
                  fontSize: 18 * widget.scale.multiplier,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.scale.label.toLowerCase(),
                style: Yapp.name(color: fg).copyWith(
                  fontWeight: widget.selected
                      ? FontWeight.w800
                      : FontWeight.w500,
                ),
              ),
            ),
            if (widget.selected)
              Text(
                '·',
                style: TextStyle(
                  color: fg,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 0.8,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
