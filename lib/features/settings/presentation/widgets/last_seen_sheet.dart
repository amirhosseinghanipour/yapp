import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../../messages/presentation/yapp_design.dart';
import '../../domain/entities/last_seen_visibility.dart';

Future<LastSeenVisibility?> showLastSeenSheet(
  BuildContext context, {
  required LastSeenVisibility current,
}) {
  return showModalBottomSheet<LastSeenVisibility>(
    context: context,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => _LastSeenBody(current: current),
  );
}

class _LastSeenBody extends StatelessWidget {
  const _LastSeenBody({required this.current});

  final LastSeenVisibility current;

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
                  'who sees my last seen',
                  style: Yapp.display().copyWith(fontSize: 28, height: 1.05),
                ),
                const SizedBox(height: 6),
                Text(
                  'also controls who can see when you are online.',
                  style: Yapp.body(color: pal.gray2),
                ),
              ],
            ),
          ),
          for (final opt in LastSeenVisibility.values)
            _Option(
              option: opt,
              selected: opt == current,
              onTap: () => Navigator.of(context).pop(opt),
            ),
          Container(height: Yapp.hairline, color: pal.ink),
        ],
      ),
    );
  }
}

class _Option extends StatefulWidget {
  const _Option({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final LastSeenVisibility option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Option> createState() => _OptionState();
}

class _OptionState extends State<_Option> {
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
            Expanded(
              child: Text(
                widget.option.label.toLowerCase(),
                style: Yapp.name(color: fg).copyWith(
                  fontWeight: widget.selected
                      ? FontWeight.w800
                      : FontWeight.w500,
                  decoration: widget.selected
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  decorationColor: fg,
                  decorationThickness: 2,
                ),
              ),
            ),
            if (widget.selected) YappGlyph.forward(color: fg, size: 22),
          ],
        ),
      ),
    );
  }
}
