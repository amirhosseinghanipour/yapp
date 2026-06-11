import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../domain/entities/chat_summary.dart';
import '../yapp_design.dart';

enum ChatAction { pin, unpin, mute, unmute, markRead, info, delete }

Future<ChatAction?> showChatActionsSheet({
  required BuildContext context,
  required ChatSummary summary,
}) {
  final pinned = summary.isPinned;
  final muted = summary.isMuted;
  final hasUnread = summary.unreadCount > 0;

  return showModalBottomSheet<ChatAction>(
    context: context,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: YappPalette.of(ctx).ink,
                  width: Yapp.hairline,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                summary.user.name.toLowerCase(),
                style: Yapp.display().copyWith(fontSize: 28),
              ),
            ),
          ),
          _Row(
            label: pinned ? 'unpin chat' : 'pin chat',
            action: pinned ? ChatAction.unpin : ChatAction.pin,
          ),
          _Row(
            label: muted ? 'unmute' : 'mute',
            action: muted ? ChatAction.unmute : ChatAction.mute,
          ),
          if (hasUnread)
            const _Row(label: 'mark as read', action: ChatAction.markRead),
          const _Row(label: 'chat info', action: ChatAction.info),
          const _Row(
            label: 'delete chat',
            action: ChatAction.delete,
            destructive: true,
          ),
        ],
      ),
    ),
  );
}

class _Row extends StatefulWidget {
  const _Row({
    required this.label,
    required this.action,
    this.destructive = false,
  });
  final String label;
  final ChatAction action;
  final bool destructive;
  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final base = widget.destructive ? pal.alert : pal.ink;
    final bg = _pressed ? base : pal.paper;
    final fg = _pressed ? pal.paper : base;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () => Navigator.of(context).pop(widget.action),
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: Yapp.name(color: fg).copyWith(fontSize: 16),
              ),
            ),
            YappGlyph.forward(color: fg),
          ],
        ),
      ),
    );
  }
}
