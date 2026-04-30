import 'dart:io';

import '../constants/app_branding.dart';

Directory getAppDataDirectory() {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null) {
      final dataDir = Directory(
        '$home/Library/Application Support/$kAppPackageName',
      );
      if (!dataDir.existsSync()) {
        dataDir.createSync(recursive: true);
      }
      return dataDir;
    }
  }

  final executablePath = Platform.resolvedExecutable;
  final executableDir = Directory(executablePath).parent;
  final dataDir = Directory('${executableDir.path}/data');
  if (!dataDir.existsSync()) {
    dataDir.createSync(recursive: true);
  }
  return dataDir;
}
