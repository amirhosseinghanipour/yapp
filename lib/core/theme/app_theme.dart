import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/messages/presentation/yapp_design.dart';
import '../../features/settings/domain/entities/chat_wallpaper.dart';
import 'yapp_palette.dart';

YappPalette _tintedPalette(
  YappPalette base,
  ChatWallpaper wallpaper,
  Brightness brightness,
) {
  if (wallpaper.isSolid) return base;
  final dark = brightness == Brightness.dark;
  final tint = (dark ? wallpaper.bottom : wallpaper.top) ?? wallpaper.top!;
  final paper = Color.lerp(base.paper, tint, dark ? 0.18 : 0.85)!;
  final gray4 = Color.lerp(paper, base.ink, dark ? 0.12 : 0.07)!;
  return base.copyWith(paper: paper, gray4: gray4);
}

ThemeData buildAppTheme({ChatWallpaper wallpaper = ChatWallpaper.none}) {
  final pal = _tintedPalette(YappPalette.light, wallpaper, Brightness.light);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: pal.paper,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
  );

  final textTheme = GoogleFonts.spaceGroteskTextTheme(
    base.textTheme,
  ).apply(bodyColor: Yapp.ink, displayColor: Yapp.ink);

  return base.copyWith(
    extensions: [pal],
    textTheme: textTheme,
    colorScheme: ColorScheme.light(
      primary: Yapp.ink,
      onPrimary: Yapp.paper,
      secondary: Yapp.ink,
      onSecondary: Yapp.paper,
      surface: pal.paper,
      onSurface: Yapp.ink,
      error: Yapp.alert,
      onError: Yapp.paper,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: pal.paper,
      foregroundColor: Yapp.ink,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: Yapp.ink, width: Yapp.hairline),
      ),
      titleTextStyle: Yapp.name().copyWith(fontSize: 16),
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: Yapp.ink,
      thickness: Yapp.hairline,
      space: Yapp.hairline,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Yapp.ink,
      contentTextStyle: Yapp.cta(),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Yapp.ink,
      circularTrackColor: Yapp.gray4,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Yapp.ink,
      selectionColor: Color(0x330A0A0A),
      selectionHandleColor: Yapp.ink,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: pal.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      modalBackgroundColor: pal.paper,
      modalElevation: 0,
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: pal.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      titleTextStyle: Yapp.display().copyWith(fontSize: 24),
      contentTextStyle: Yapp.body(color: Yapp.gray2),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Yapp.paper : Yapp.ink,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Yapp.ink : Yapp.paper,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Yapp.ink),
      trackOutlineWidth: const WidgetStatePropertyAll(Yapp.hairline),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Yapp.ink,
      unselectedLabelColor: Yapp.gray2,
      indicatorColor: Yapp.ink,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Yapp.ink,
      labelStyle: Yapp.cta(color: Yapp.ink).copyWith(fontSize: 13),
      unselectedLabelStyle: Yapp.cta(color: Yapp.gray2).copyWith(fontSize: 13),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Yapp.ink.withValues(alpha: 0.35)),
      radius: const Radius.circular(0),
    ),
    iconTheme: const IconThemeData(color: Yapp.ink),
    splashFactory: NoSplash.splashFactory,
  );
}

ThemeData buildAppDarkTheme({ChatWallpaper wallpaper = ChatWallpaper.none}) {
  const darkInk = Color(0xFFF5F5F5);
  const darkPaper = Color(0xFF000000);
  const darkGray = Color(0xFF9A9A9A);
  final pal = _tintedPalette(YappPalette.dark, wallpaper, Brightness.dark);

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: pal.paper,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
  );

  final textTheme = GoogleFonts.spaceGroteskTextTheme(
    base.textTheme,
  ).apply(bodyColor: darkInk, displayColor: darkInk);

  return base.copyWith(
    extensions: [pal],
    textTheme: textTheme,
    colorScheme: ColorScheme.dark(
      primary: darkInk,
      onPrimary: darkPaper,
      secondary: darkInk,
      onSecondary: darkPaper,
      surface: pal.paper,
      onSurface: darkInk,
      error: Yapp.alert,
      onError: darkInk,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: pal.paper,
      foregroundColor: darkInk,
      surfaceTintColor: Colors.transparent,
      shape: const Border(
        bottom: BorderSide(color: darkInk, width: Yapp.hairline),
      ),
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: darkInk,
        letterSpacing: -0.1,
      ),
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: darkInk,
      thickness: Yapp.hairline,
      space: Yapp.hairline,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkInk,
      contentTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: darkPaper,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: darkInk,
      circularTrackColor: darkGray,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: darkInk,
      selectionColor: Color(0x33FFFFFF),
      selectionHandleColor: darkInk,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: pal.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      modalBackgroundColor: pal.paper,
      modalElevation: 0,
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: pal.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      titleTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: darkInk,
        letterSpacing: -0.2,
      ),
      contentTextStyle: GoogleFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: darkGray,
        height: 1.35,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? darkPaper : darkInk,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? darkInk : darkPaper,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(darkInk),
      trackOutlineWidth: const WidgetStatePropertyAll(Yapp.hairline),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: darkInk,
      unselectedLabelColor: darkGray,
      indicatorColor: darkInk,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: darkInk,
      labelStyle: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: darkInk,
      ),
      unselectedLabelStyle: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: darkGray,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(darkInk.withValues(alpha: 0.35)),
      radius: const Radius.circular(0),
    ),
    iconTheme: const IconThemeData(color: darkInk),
    splashFactory: NoSplash.splashFactory,
  );
}
