import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../yapp_design.dart';

class DeleteMessageChoice {
  const DeleteMessageChoice({required this.deleteChat});
  final bool deleteChat;
}

class DeleteChatChoice {
  const DeleteChatChoice({required this.forEveryone});
  final bool forEveryone;
}

Future<DeleteChatChoice?> showDeleteChatSheet(
  BuildContext context, {
  required String peerName,
}) {
  return showModalBottomSheet<DeleteChatChoice>(
    context: context,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    isScrollControlled: true,
    builder: (_) => _DeleteChatSheet(peerName: peerName),
  );
}

class _DeleteChatSheet extends StatefulWidget {
  const _DeleteChatSheet({required this.peerName});
  final String peerName;

  @override
  State<_DeleteChatSheet> createState() => _DeleteChatSheetState();
}

class _DeleteChatSheetState extends State<_DeleteChatSheet> {
  bool _forEveryone = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final name = widget.peerName.toLowerCase();
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'delete chat',
                  style: Yapp.display().copyWith(fontSize: 28, height: 1.05),
                ),
                const SizedBox(height: 10),
                Text(
                  _forEveryone
                      ? 'this wipes the conversation for both of you.'
                      : 'this clears the conversation on your device only.',
                  style: Yapp.body(
                    color: pal.gray2,
                  ).copyWith(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          _CheckRow(
            label: 'also delete for $name',
            checked: _forEveryone,
            onTap: () => setState(() => _forEveryone = !_forEveryone),
          ),
          Container(height: Yapp.hairline, color: pal.ink),
          _StampRow(
            label: 'delete chat  →',
            fill: pal.alert,
            textColor: pal.paper,
            onTap: () => Navigator.of(
              context,
            ).pop(DeleteChatChoice(forEveryone: _forEveryone)),
          ),
          Container(height: Yapp.hairline, color: pal.ink),
          _StampRow(
            label: 'cancel',
            fill: pal.paper,
            textColor: pal.ink,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

Future<DeleteMessageChoice?> showDeleteMessageSheet(BuildContext context) {
  return showModalBottomSheet<DeleteMessageChoice>(
    context: context,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    isScrollControlled: true,
    builder: (_) => const _DeleteMessageSheet(),
  );
}

class _DeleteMessageSheet extends StatefulWidget {
  const _DeleteMessageSheet();

  @override
  State<_DeleteMessageSheet> createState() => _DeleteMessageSheetState();
}

class _DeleteMessageSheetState extends State<_DeleteMessageSheet> {
  bool _deleteChat = false;

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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'delete message',
                  style: Yapp.display().copyWith(fontSize: 28, height: 1.05),
                ),
                const SizedBox(height: 10),
                Text(
                  'this removes it for both of you.',
                  style: Yapp.body(
                    color: pal.gray2,
                  ).copyWith(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          _CheckRow(
            label: 'also delete this chat for both of us',
            checked: _deleteChat,
            onTap: () => setState(() => _deleteChat = !_deleteChat),
          ),
          Container(height: Yapp.hairline, color: pal.ink),
          _StampRow(
            label: '${_deleteChat ? 'delete chat' : 'delete'}  →',
            fill: pal.alert,
            textColor: pal.paper,
            onTap: () => Navigator.of(
              context,
            ).pop(DeleteMessageChoice(deleteChat: _deleteChat)),
          ),
          Container(height: Yapp.hairline, color: pal.ink),
          _StampRow(
            label: 'cancel',
            fill: pal.paper,
            textColor: pal.ink,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          children: [
            AnimatedContainer(
              duration: Yapp.dur,
              curve: Yapp.curve,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? pal.ink : pal.paper,
                border: Border.all(color: pal.ink, width: 1.5),
              ),
              alignment: Alignment.center,
              child: checked
                  ? Icon(Icons.check, size: 16, color: pal.paper)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Yapp.name(color: pal.ink).copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
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
