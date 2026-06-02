import 'dart:io';

import 'package:flutter/material.dart';

import '../core/platform.dart';

const _fontFamilyFallback = [
  'system-font',
  'sans-serif',
  'Microsoft YaHei',
];

extension ChineseTextTheme on TextTheme {
  static final Typography _typography = Typography.material2021();

  TextTheme _fixChinese(Brightness brightness) {
    final newTextTheme = switch (brightness) {
      Brightness.dark =>
        _typography.white.apply(fontFamilyFallback: _fontFamilyFallback),
      Brightness.light =>
        _typography.black.apply(fontFamilyFallback: _fontFamilyFallback),
    };
    return newTextTheme.merge(this);
  }
}

extension ChineseThemeData on ThemeData {
  ThemeData get fixWindowsFont {
    if (!isWindows) return this;

    return switch (Platform.localeName) {
      final locale when locale.startsWith('zh') =>
        copyWith(textTheme: textTheme._fixChinese(brightness)),
      _ => this,
    };
  }
}
