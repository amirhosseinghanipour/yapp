import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../domain/entities/reply_preview.dart';
import '../yapp_design.dart';

class ReplyPreviewBar extends StatelessWidget {
  const ReplyPreviewBar({
    super.key,
    required this.reply,
    required this.onClear,
  });

  final ReplyPreview reply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pal.paper,
        border: Border(top: BorderSide(color: pal.ink, width: 1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: pal.ink),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'replying to ${reply.senderName.toLowerCase()}:',
                      style: Yapp.label(
                        color: pal.gray2,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summary(reply).toLowerCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Yapp.bubble(color: pal.ink),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: YappGlyph.close(color: pal.ink, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _summary(ReplyPreview r) => r.text ?? '';
}
