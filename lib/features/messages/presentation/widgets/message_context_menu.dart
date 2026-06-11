import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../yapp_design.dart';

enum MessageAction {
  reply,
  copy,
  edit,
  forward,
  pin,
  unpin,
  delete,
  react,
  save,
}

class MessageContextMenuResult {
  const MessageContextMenuResult({required this.action, this.emoji});
  final MessageAction action;
  final String? emoji;
}

class MessageContextMenuItem {
  const MessageContextMenuItem({
    required this.action,
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final MessageAction action;

  final IconData icon;
  final String label;
  final bool danger;
}

Future<MessageContextMenuResult?> showMessageContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<MessageContextMenuItem> items,
  List<String> quickReactions = const ['❤️', '👍', '😂', '😮', '😢', '🔥'],
}) {
  return showModalBottomSheet<MessageContextMenuResult?>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: false,
    builder: (ctx) =>
        _YappContextSheet(items: items, reactions: quickReactions),
  );
}

class _YappContextSheet extends StatelessWidget {
  const _YappContextSheet({required this.items, required this.reactions});

  final List<MessageContextMenuItem> items;
  final List<String> reactions;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return SafeArea(
      top: false,
      child: Container(
        color: pal.paper,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reactions.isNotEmpty)
              _ReactionStrip(
                emojis: reactions,
                onPick: (e) => Navigator.of(context).pop(
                  MessageContextMenuResult(
                    action: MessageAction.react,
                    emoji: e,
                  ),
                ),
              ),
            for (var i = 0; i < items.length; i++) ...[
              _ActionRow(
                label: items[i].label.toLowerCase(),
                danger: items[i].danger,
                onTap: () => Navigator.of(
                  context,
                ).pop(MessageContextMenuResult(action: items[i].action)),
              ),
              if (i != items.length - 1) Container(height: 1, color: pal.gray4),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReactionStrip extends StatelessWidget {
  const _ReactionStrip({required this.emojis, required this.onPick});

  final List<String> emojis;
  final void Function(String emoji) onPick;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      width: double.infinity,
      color: pal.ink,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final e in emojis)
            InkWell(
              onTap: () => onPick(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(e, style: const TextStyle(fontSize: 26)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.danger,
    required this.onTap,
  });

  final String label;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final color = danger ? pal.alert : pal.ink;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Yapp.name(
                    color: color,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              YappGlyph.forward(color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
