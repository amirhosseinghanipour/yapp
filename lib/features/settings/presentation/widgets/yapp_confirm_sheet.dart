import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../../messages/presentation/yapp_design.dart';

Future<bool?> showYappConfirmSheet(
  BuildContext context, {
  required String headline,
  String? body,
  required String primaryLabel,
  String cancelLabel = 'cancel',
  bool destructive = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    isScrollControlled: true,
    builder: (ctx) => _YappConfirmSheet(
      headline: headline,
      body: body,
      primaryLabel: primaryLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
}

class _YappConfirmSheet extends StatelessWidget {
  const _YappConfirmSheet({
    required this.headline,
    required this.body,
    required this.primaryLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String headline;
  final String? body;
  final String primaryLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline.toLowerCase(),
                  style: Yapp.display().copyWith(fontSize: 28, height: 1.05),
                ),
                if (body != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    body!.toLowerCase(),
                    style: Yapp.body(
                      color: pal.gray2,
                    ).copyWith(fontSize: 14, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          _StampRow(
            label: '${primaryLabel.toLowerCase()}  →',
            fill: destructive ? pal.alert : pal.ink,
            textColor: pal.paper,
            onTap: () => Navigator.of(context).pop(true),
          ),
          Container(height: Yapp.hairline, color: pal.ink),
          _StampRow(
            label: cancelLabel.toLowerCase(),
            fill: pal.paper,
            textColor: pal.ink,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

class _StampRow extends StatefulWidget {
  const _StampRow({
    required this.label,
    required this.fill,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final VoidCallback onTap;

  @override
  State<_StampRow> createState() => _StampRowState();
}

class _StampRowState extends State<_StampRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = _pressed ? widget.textColor : widget.fill;
    final fg = _pressed ? widget.fill : widget.textColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        height: 56,
        color: bg,
        alignment: Alignment.center,
        child: Text(widget.label, style: Yapp.cta(color: fg)),
      ),
    );
  }
}
