import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/message.dart';
import '../../domain/entities/message_status.dart';
import '../../domain/entities/reply_preview.dart';
import '../../domain/repositories/messenger_repository.dart';
import '../../../../core/theme/yapp_palette.dart';
import '../yapp_design.dart';
import 'media_bubble_content.dart';
import 'rich_text_message.dart';

bool _bubbleFaceIsDark(BuildContext context, bool mine) {
  final p = YappPalette.of(context);
  final bg = mine ? p.bubbleMineBg : p.bubbleTheirsBg;
  return bg.computeLuminance() <= 0.42;
}

Color _bubblePrimaryFg(BuildContext context, bool mine) {
  return _bubbleFaceIsDark(context, mine) ? Yapp.paper : Yapp.ink;
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.messenger,
    this.onReplyHeaderTap,
    this.onReactionTap,
    this.highlight = false,
    this.groupPosition = BubbleGroupPosition.standalone,
    this.autoDownloadMedia = true,
  });

  final Message message;
  final bool isMine;

  final MessengerRepository? messenger;

  final bool autoDownloadMedia;
  final void Function(String messageId)? onReplyHeaderTap;
  final void Function(String emoji)? onReactionTap;
  final bool highlight;

  final BubbleGroupPosition groupPosition;

  bool get _isLastInGroup =>
      groupPosition == BubbleGroupPosition.standalone ||
      groupPosition == BubbleGroupPosition.last;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final wrapped = AnimatedContainer(
      duration: Yapp.dur,
      curve: Yapp.curve,
      decoration: BoxDecoration(
        border: Border.all(
          color: highlight ? Yapp.alert : Colors.transparent,
          width: 1,
        ),
      ),
      child: content,
    );

    return Column(
      crossAxisAlignment: align,
      children: [
        wrapped,
        if (message.reactions.isNotEmpty && _isLastInGroup) ...[
          const SizedBox(height: 6),
          _YappReactions(
            reactions: message.reactions,
            isMine: isMine,
            onTap: onReactionTap,
          ),
        ],
        if (_isLastInGroup) ...[
          const SizedBox(height: 4),
          _MetaLine(message: message, isMine: isMine),
        ],
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return _TextBlock(
      message: message,
      isMine: isMine,
      messenger: messenger,
      onReplyHeaderTap: onReplyHeaderTap,
      groupPosition: groupPosition,
      autoDownloadMedia: autoDownloadMedia,
    );
  }
}

enum BubbleGroupPosition { standalone, first, middle, last }

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final p = YappPalette.of(context);
    final time = DateFormat('HH:mm').format(message.timestamp);
    final status = message.status;
    final tick = _tickFor(status);
    final tickColor =
        status == MessageStatus.read || status == MessageStatus.failed
        ? p.alert
        : p.gray2;

    return Padding(
      padding: EdgeInsets.only(left: isMine ? 0 : 4, right: isMine ? 4 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (message.editedAt != null) ...[
            Text(
              'edited',
              style: Yapp.meta(
                color: p.gray2,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(width: 6),
          ],
          Text(time, style: Yapp.meta(color: p.gray2)),
          if (isMine && tick != null) ...[
            const SizedBox(width: 6),
            Text(
              tick,
              style: Yapp.meta(color: tickColor).copyWith(
                fontWeight: status == MessageStatus.read
                    ? FontWeight.w800
                    : FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _tickFor(MessageStatus s) {
    switch (s) {
      case MessageStatus.sending:
        return YappTicks.sending;
      case MessageStatus.sent:
        return YappTicks.sent;
      case MessageStatus.delivered:
        return YappTicks.delivered;
      case MessageStatus.read:
        return YappTicks.read;
      case MessageStatus.failed:
        return YappTicks.failed;
    }
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.message,
    required this.isMine,
    required this.groupPosition,
    this.messenger,
    this.onReplyHeaderTap,
    this.autoDownloadMedia = true,
  });

  final Message message;
  final bool isMine;
  final BubbleGroupPosition groupPosition;
  final MessengerRepository? messenger;
  final void Function(String messageId)? onReplyHeaderTap;
  final bool autoDownloadMedia;

  bool get _isFirst =>
      groupPosition == BubbleGroupPosition.standalone ||
      groupPosition == BubbleGroupPosition.first;

  bool get _isLast =>
      groupPosition == BubbleGroupPosition.standalone ||
      groupPosition == BubbleGroupPosition.last;

  @override
  Widget build(BuildContext context) {
    final textColor = _bubblePrimaryFg(context, isMine);
    final onDark = _bubbleFaceIsDark(context, isMine);
    final baseStyle = Yapp.bubble(color: textColor);
    final isMedia = message.isMedia;
    final caption = (message.text ?? '').trim();
    final hasCaption = caption.isNotEmpty;
    final maxBubble =
        MediaQuery.sizeOf(context).width * Yapp.bubbleMaxWidthFraction;
    final mediaW = (maxBubble - 28).clamp(180.0, 300.0);
    final msgDir = Yapp.dirFor(caption) ?? Directionality.of(context);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubble),
        child: _Block(
          isMine: isMine,
          showTopHairline: !_isFirst,
          showCornerTick: _isLast,
          child: Directionality(
            textDirection: msgDir,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: SizedBox(
                width: isMedia ? mediaW : null,
                child: Column(
                  crossAxisAlignment: isMedia
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.forwardedFromName != null && _isFirst)
                      _ForwardedStrip(
                        name: message.forwardedFromName!,
                        onDark: onDark,
                      ),
                    if (message.replyTo != null && _isFirst)
                      _ReplyHeader(
                        reply: message.replyTo!,
                        onDark: onDark,
                        onTap: onReplyHeaderTap == null
                            ? null
                            : () =>
                                  onReplyHeaderTap!(message.replyTo!.messageId),
                      ),
                    if (isMedia)
                      MediaBubbleContent(
                        message: message,
                        isMine: isMine,
                        onDark: onDark,
                        messenger: messenger,
                        autoDownload: autoDownloadMedia,
                      ),
                    if (isMedia && hasCaption) const SizedBox(height: 8),
                    if (!isMedia || hasCaption)
                      RichTextMessage(
                        text: caption,
                        baseStyle: baseStyle,
                        onDark: onDark,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.isMine,
    required this.child,
    this.showTopHairline = false,
    this.showCornerTick = false,
  });

  final bool isMine;
  final Widget child;
  final bool showTopHairline;
  final bool showCornerTick;

  @override
  Widget build(BuildContext context) {
    final p = YappPalette.of(context);
    final bg = isMine ? p.bubbleMineBg : p.bubbleTheirsBg;
    final divider = isMine ? p.paper.withValues(alpha: 0.18) : p.ink;
    final tickColor = isMine ? p.paper : p.ink;

    final rect = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: isMine ? null : Border.all(color: p.ink, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTopHairline)
              SizedBox(height: 1, child: ColoredBox(color: divider)),
            child,
          ],
        ),
      ),
    );

    if (!showCornerTick) return rect;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        rect,
        Positioned(
          right: isMine ? -Yapp.bubbleTickSize - 2 : null,
          left: isMine ? null : -Yapp.bubbleTickSize - 2,
          bottom: 0,
          child: Container(
            width: Yapp.bubbleTickSize,
            height: Yapp.bubbleTickSize,
            color: tickColor,
          ),
        ),
      ],
    );
  }
}

class _ReplyHeader extends StatelessWidget {
  const _ReplyHeader({required this.reply, required this.onDark, this.onTap});

  final ReplyPreview reply;
  final bool onDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = YappPalette.of(context);
    final barColor = onDark ? p.paper : p.ink;
    final nameColor = onDark ? p.paper : p.ink;
    final previewColor = onDark ? p.paper.withValues(alpha: 0.7) : p.gray2;

    final card = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: barColor),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reply.senderName.toLowerCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Yapp.label(
                    color: nameColor,
                  ).copyWith(fontWeight: FontWeight.w700),
                  textDirection: Yapp.dirFor(reply.senderName),
                ),
                const SizedBox(height: 2),
                Builder(
                  builder: (_) {
                    final preview = _previewFor(reply).toLowerCase();
                    return Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Yapp.body(color: previewColor),
                      textDirection: Yapp.dirFor(preview),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(onTap: onTap, child: card);
  }

  static String _previewFor(ReplyPreview r) {
    if (r.text != null && r.text!.isNotEmpty) return r.text!;
    return '';
  }
}

class _ForwardedStrip extends StatelessWidget {
  const _ForwardedStrip({required this.name, required this.onDark});
  final String name;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final p = YappPalette.of(context);
    final color = onDark ? p.paper : p.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        'forwarded · ${name.toLowerCase()}',
        style: Yapp.label(
          color: color,
        ).copyWith(fontWeight: FontWeight.w700, fontSize: 10),
        textDirection: Yapp.dirFor(name),
      ),
    );
  }
}

class _YappReactions extends StatelessWidget {
  const _YappReactions({
    required this.reactions,
    required this.isMine,
    required this.onTap,
  });

  final Map<String, List<String>> reactions;
  final bool isMine;
  final void Function(String emoji)? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final e in reactions.entries)
          _ReactionSquare(
            emoji: e.key,
            count: e.value.length,
            mineReacted: e.value.contains('user_me'),
            onTap: () => onTap?.call(e.key),
          ),
      ],
    );
  }
}

class _ReactionSquare extends StatelessWidget {
  const _ReactionSquare({
    required this.emoji,
    required this.count,
    required this.mineReacted,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool mineReacted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = YappPalette.of(context);
    final bg = mineReacted ? p.ink : p.paper;
    final fg = mineReacted ? p.paper : p.ink;
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: p.ink, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14, height: 1)),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: Yapp.label(
                  color: fg,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
