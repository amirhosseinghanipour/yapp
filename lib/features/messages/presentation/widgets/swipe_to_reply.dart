import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../yapp_design.dart';

class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.alignStart = true,
    this.threshold = 64,
  });

  final Widget child;
  final VoidCallback onReply;

  final bool alignStart;

  final double threshold;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  double _drag = 0;
  bool _fired = false;

  @override
  Widget build(BuildContext context) {
    final sign = widget.alignStart ? 1.0 : -1.0;
    final progress = (_drag.abs() / widget.threshold).clamp(0.0, 1.0);
    final palette = YappPalette.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        setState(() {
          final raw = _drag + d.delta.dx;
          if (sign > 0) {
            _drag = raw.clamp(0.0, widget.threshold + 30);
          } else {
            _drag = raw.clamp(-(widget.threshold + 30), 0.0);
          }
        });
        if (!_fired && _drag.abs() >= widget.threshold) {
          _fired = true;
          HapticFeedback.selectionClick();
          widget.onReply();
        }
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          _drag = 0;
          _fired = false;
        });
      },
      child: Stack(
        alignment: widget.alignStart
            ? Alignment.centerLeft
            : Alignment.centerRight,
        children: [
          Opacity(
            opacity: progress,
            child: Padding(
              padding: EdgeInsets.only(
                left: widget.alignStart ? 8 : 0,
                right: widget.alignStart ? 0 : 8,
              ),
              child: Container(
                width: 28 + progress * 6,
                height: 28 + progress * 6,
                decoration: BoxDecoration(
                  color: palette.paper,
                  border: Border.all(color: palette.ink, width: Yapp.hairline),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.alignStart
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: 14 + progress * 2,
                  color: palette.ink,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_drag * 0.6, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
