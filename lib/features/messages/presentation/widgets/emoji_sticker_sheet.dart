import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';

sealed class EmojiSheetResult {
  const EmojiSheetResult();
}

class EmojiInsert extends EmojiSheetResult {
  const EmojiInsert(this.emoji);
  final String emoji;
}

class EmojiBackspace extends EmojiSheetResult {
  const EmojiBackspace();
}

class EmojiStickerSheet extends StatelessWidget {
  const EmojiStickerSheet({
    super.key,
    required this.onResult,
    this.height = 320,
  });

  final ValueChanged<EmojiSheetResult> onResult;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return SizedBox(
      height: height,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) =>
            onResult(EmojiInsert(emoji.emoji)),
        onBackspacePressed: () => onResult(const EmojiBackspace()),
        config: Config(
          height: height,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            backgroundColor: pal.paper,
            emojiSizeMax: 28,
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: pal.paper,
            indicatorColor: pal.ink,
            iconColorSelected: pal.ink,
            iconColor: pal.gray3,
          ),
          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
        ),
      ),
    );
  }
}
