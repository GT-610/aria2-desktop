import 'dart:io';

import 'package:flutter/foundation.dart';

enum Pfs {
  android,
  ios,
  linux,
  macos,
  windows,
  web,
  fuchsia,
  unknown;

  static final type = () {
    if (kIsWeb) return web;
    return switch (Platform.operatingSystem) {
      'android' => android,
      'ios' => ios,
      'linux' => linux,
      'macos' => macos,
      'windows' => windows,
      'fuchsia' => fuchsia,
      _ => unknown,
    };
  }();

  static final String separator = isWindows ? '\\' : '/';

  static final String? homeDir = () {
    final envVars = Platform.environment;
    if (isMacOS || isLinux) {
      return envVars['HOME'];
    } else if (isWindows) {
      return envVars['UserProfile'];
    }
    return null;
  }();
}

final isLinux = Pfs.type == Pfs.linux;
final isMacOS = Pfs.type == Pfs.macos;
final isWindows = Pfs.type == Pfs.windows;
final isDesktop =
    Pfs.type == Pfs.linux || Pfs.type == Pfs.macos || Pfs.type == Pfs.windows;
