import 'package:flutter/material.dart';

enum ChatWallpaper {
  none('Default', null, null),
  sky('Sky', Color(0xFFDDEBFB), Color(0xFFC6DFFB)),
  mint('Mint', Color(0xFFE2F3EC), Color(0xFFCDEADC)),
  sand('Sand', Color(0xFFF6EEDB), Color(0xFFEADFC4)),
  rose('Rose', Color(0xFFF7E1E6), Color(0xFFEFCDD7)),
  lavender('Lavender', Color(0xFFE8E3F6), Color(0xFFD7CFEC)),
  charcoal('Charcoal', Color(0xFF1B1C21), Color(0xFF2A2C35));

  const ChatWallpaper(this.label, this.top, this.bottom);

  final String label;

  final Color? top;
  final Color? bottom;

  bool get isSolid => top == null || bottom == null;

  String get storageValue => name;

  static ChatWallpaper fromStorage(String? raw) {
    for (final v in ChatWallpaper.values) {
      if (v.name == raw) return v;
    }
    return ChatWallpaper.none;
  }

  BoxDecoration chatListDecoration({
    required Brightness brightness,
    required Color basePaper,
  }) {
    if (isSolid || top == null || bottom == null) {
      return BoxDecoration(color: basePaper);
    }
    final t = top!;
    final b = bottom!;
    final Color topC;
    final Color botC;
    if (brightness == Brightness.dark) {
      topC = Color.lerp(basePaper, t, 0.55)!;
      botC = Color.lerp(basePaper, b, 0.55)!;
    } else {
      topC = t;
      botC = b;
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topC, botC],
      ),
    );
  }
}
