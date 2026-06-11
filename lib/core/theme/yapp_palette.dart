import 'package:flutter/material.dart';

@immutable
class YappPalette extends ThemeExtension<YappPalette> {
  const YappPalette({
    required this.ink,
    required this.paper,
    required this.gray1,
    required this.gray2,
    required this.gray3,
    required this.gray4,
    required this.alert,
    required this.pressWash,
    required this.bubbleMineBg,
    required this.bubbleTheirsBg,
    required this.bubbleTheirsBorder,
  });

  final Color ink;
  final Color paper;
  final Color gray1;
  final Color gray2;
  final Color gray3;
  final Color gray4;
  final Color alert;
  final Color pressWash;
  final Color bubbleMineBg;
  final Color bubbleTheirsBg;
  final Color bubbleTheirsBorder;

  static YappPalette of(BuildContext context) {
    return Theme.of(context).extension<YappPalette>() ?? YappPalette.light;
  }

  static const YappPalette light = YappPalette(
    ink: Color(0xFF0A0A0A),
    paper: Color(0xFFFFFFFF),
    gray1: Color(0xFF0A0A0A),
    gray2: Color(0xFF6B6B6B),
    gray3: Color(0xFFB8B8B8),
    gray4: Color(0xFFF2F2F2),
    alert: Color(0xFFFF3B30),
    pressWash: Color(0x0A0A0A0A),
    bubbleMineBg: Color(0xFF0A0A0A),
    bubbleTheirsBg: Color(0xFFFFFFFF),
    bubbleTheirsBorder: Color(0xFF0A0A0A),
  );

  static const YappPalette dark = YappPalette(
    ink: Color(0xFFF5F5F5),
    paper: Color(0xFF000000),
    gray1: Color(0xFFF5F5F5),
    gray2: Color(0xFF9A9A9A),
    gray3: Color(0xFF5C5C5C),
    gray4: Color(0xFF1A1A1A),
    alert: Color(0xFFFF453A),
    pressWash: Color(0x14FFFFFF),
    bubbleMineBg: Color(0xFFF5F5F5),
    bubbleTheirsBg: Color(0xFF161616),
    bubbleTheirsBorder: Color(0xFFF5F5F5),
  );

  @override
  YappPalette copyWith({
    Color? ink,
    Color? paper,
    Color? gray1,
    Color? gray2,
    Color? gray3,
    Color? gray4,
    Color? alert,
    Color? pressWash,
    Color? bubbleMineBg,
    Color? bubbleTheirsBg,
    Color? bubbleTheirsBorder,
  }) {
    return YappPalette(
      ink: ink ?? this.ink,
      paper: paper ?? this.paper,
      gray1: gray1 ?? this.gray1,
      gray2: gray2 ?? this.gray2,
      gray3: gray3 ?? this.gray3,
      gray4: gray4 ?? this.gray4,
      alert: alert ?? this.alert,
      pressWash: pressWash ?? this.pressWash,
      bubbleMineBg: bubbleMineBg ?? this.bubbleMineBg,
      bubbleTheirsBg: bubbleTheirsBg ?? this.bubbleTheirsBg,
      bubbleTheirsBorder: bubbleTheirsBorder ?? this.bubbleTheirsBorder,
    );
  }

  @override
  YappPalette lerp(ThemeExtension<YappPalette>? other, double t) {
    if (other is! YappPalette) return this;
    return YappPalette(
      ink: Color.lerp(ink, other.ink, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      gray1: Color.lerp(gray1, other.gray1, t)!,
      gray2: Color.lerp(gray2, other.gray2, t)!,
      gray3: Color.lerp(gray3, other.gray3, t)!,
      gray4: Color.lerp(gray4, other.gray4, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      pressWash: Color.lerp(pressWash, other.pressWash, t)!,
      bubbleMineBg: Color.lerp(bubbleMineBg, other.bubbleMineBg, t)!,
      bubbleTheirsBg: Color.lerp(bubbleTheirsBg, other.bubbleTheirsBg, t)!,
      bubbleTheirsBorder: Color.lerp(
        bubbleTheirsBorder,
        other.bubbleTheirsBorder,
        t,
      )!,
    );
  }
}
