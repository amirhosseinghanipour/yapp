import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../../messages/presentation/yapp_design.dart';
import '../../domain/entities/chat_wallpaper.dart';

Future<ChatWallpaper?> showWallpaperSheet(
  BuildContext context, {
  required ChatWallpaper current,
}) {
  return showModalBottomSheet<ChatWallpaper>(
    context: context,
    isScrollControlled: true,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.62;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: _WallpaperSheetBody(current: current),
          ),
        ),
      );
    },
  );
}

class _WallpaperSheetBody extends StatelessWidget {
  const _WallpaperSheetBody({required this.current});

  final ChatWallpaper current;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final options = ChatWallpaper.values;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'app color',
          style: Yapp.display().copyWith(fontSize: 28, height: 1.05),
        ),
        const SizedBox(height: 6),
        Text(
          'tints the whole app, not just chats.',
          style: Yapp.body(color: pal.gray2),
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: [
            for (final w in options)
              _WallpaperTile(
                wallpaper: w,
                selected: w == current,
                onTap: () => Navigator.of(context).pop(w),
              ),
          ],
        ),
      ],
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.wallpaper,
    required this.selected,
    required this.onTap,
  });

  final ChatWallpaper wallpaper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final preview = wallpaper.isSolid
        ? Container(color: pal.paper)
        : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [wallpaper.top!, wallpaper.bottom!],
              ),
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: pal.ink,
                  width: selected ? 2 : Yapp.hairline,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: preview),
                  Positioned(
                    left: 8,
                    top: 10,
                    child: Container(
                      width: 40,
                      height: 10,
                      color: pal.paper,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: Border.all(
                          color: pal.ink,
                          width: Yapp.hairline,
                        ).boxOnly(),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 10,
                    child: Container(width: 32, height: 10, color: pal.ink),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: selected ? 36 : 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? pal.ink : pal.paper,
              border: Border(
                left: BorderSide(
                  color: pal.ink,
                  width: selected ? 2 : Yapp.hairline,
                ),
                right: BorderSide(
                  color: pal.ink,
                  width: selected ? 2 : Yapp.hairline,
                ),
                bottom: BorderSide(
                  color: pal.ink,
                  width: selected ? 2 : Yapp.hairline,
                ),
              ),
            ),
            child: Text(
              wallpaper.label.toLowerCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Yapp.name(color: selected ? pal.paper : pal.ink).copyWith(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on Border {
  BoxDecoration boxOnly() => BoxDecoration(border: this);
}
