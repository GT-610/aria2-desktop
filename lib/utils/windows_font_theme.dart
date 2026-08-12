import 'dart:io';

import 'package:flutter/material.dart';

const _fontFamilyFallback = <String>[
  'system-font',
  'sans-serif',
  'Microsoft YaHei',
];

extension WindowsFontTheme on ThemeData {
  ThemeData get withWindowsChineseFontFallback {
    if (!Platform.isWindows || !Platform.localeName.startsWith('zh')) {
      return this;
    }
    final typography = Typography.material2021();
    final platformTextTheme = switch (brightness) {
      Brightness.dark => typography.white,
      Brightness.light => typography.black,
    };
    return copyWith(
      textTheme: platformTextTheme
          .apply(fontFamilyFallback: _fontFamilyFallback)
          .merge(textTheme),
    );
  }
}
