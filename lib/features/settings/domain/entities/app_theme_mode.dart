import 'package:flutter/material.dart';

enum AppThemeMode {
  light('light'),
  dark('dark'),
  system('system');

  const AppThemeMode(this.storageValue);

  final String storageValue;

  static AppThemeMode fromStorage(String? value) {
    for (final mode in AppThemeMode.values) {
      if (mode.storageValue == value) return mode;
    }
    return AppThemeMode.system;
  }

  ThemeMode toFlutter() => switch (this) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
}
