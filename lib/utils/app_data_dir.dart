import 'dart:io';

import 'app_paths.dart';

Directory getAppDataDirectory() {
  final dataDir = AppPaths.instance.supportDirectory;
  if (!dataDir.existsSync()) {
    dataDir.createSync(recursive: true);
  }
  return dataDir;
}
