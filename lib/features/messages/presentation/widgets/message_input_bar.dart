import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../yapp_design.dart';

class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    required this.controller,
    required this.emojiToggled,
    required this.onToggleEmoji,
    required this.onSendText,
    this.onAttach,
    this.focusNode,
    this.editing = false,
    this.editingPreview,
    this.onCancelEdit,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool emojiToggled;
  final VoidCallback onToggleEmoji;
  final VoidCallback onSendText;

  final VoidCallback? onAttach;
  final bool editing;
  final String? editingPreview;
  final VoidCallback? onCancelEdit;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  static const double _control = 44;

  bool _hasText = false;
  bool _sendPressed = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() {
    final next = widget.controller.text.trim().isNotEmpty;
    if (next != _hasText) setState(() => _hasText = next);
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final showAttach = widget.onAttach != null && !widget.editing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: pal.paper,
        border: Border(
          top: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _BarIconButton(
                size: _control,
                icon: widget.emojiToggled
                    ? Icons.keyboard_alt_outlined
                    : Icons.emoji_emotions_outlined,
                onTap: widget.onToggleEmoji,
              ),
              if (showAttach)
                _BarIconButton(
                  size: _control,
                  icon: Icons.attach_file_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onAttach!();
                  },
                ),
              const SizedBox(width: 4),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _control),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    maxLines: 6,
                    minLines: 1,
                    textAlignVertical: TextAlignVertical.center,
                    style: Yapp.body(color: pal.ink).copyWith(fontSize: 15),
                    cursorColor: pal.ink,
                    decoration: InputDecoration(
                      hintText: widget.editing ? 'edit message' : 'message',
                      hintStyle: Yapp.body(
                        color: pal.gray3,
                      ).copyWith(fontSize: 15),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTapDown: (_) => setState(() => _sendPressed = true),
                onTapUp: (_) => setState(() => _sendPressed = false),
                onTapCancel: () => setState(() => _sendPressed = false),
                onTap: _hasText
                    ? () {
                        HapticFeedback.lightImpact();
                        widget.onSendText();
                      }
                    : null,
                child: AnimatedContainer(
                  duration: Yapp.dur,
                  curve: Yapp.curve,
                  width: _control,
                  height: _control,
                  alignment: Alignment.center,
                  color: _hasText
                      ? (_sendPressed ? pal.gray2 : pal.ink)
                      : pal.gray4,
                  child: Icon(
                    widget.editing
                        ? Icons.check_rounded
                        : Icons.arrow_upward_rounded,
                    color: _hasText ? pal.paper : pal.gray3,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarIconButton extends StatefulWidget {
  const _BarIconButton({
    required this.icon,
    required this.onTap,
    required this.size,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  State<_BarIconButton> createState() => _BarIconButtonState();
}

class _BarIconButtonState extends State<_BarIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        color: _pressed ? pal.pressWash : Colors.transparent,
        child: Icon(widget.icon, color: pal.ink, size: 24),
      ),
    );
  }
}
