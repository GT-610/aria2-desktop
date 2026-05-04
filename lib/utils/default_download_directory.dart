import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_data_dir.dart';

String getDefaultDownloadDirectorySync() {
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE']?.trim();
    if (userProfile != null && userProfile.isNotEmpty) {
      return p.normalize(p.join(userProfile, 'Downloads'));
    }
  }

  final home =
      Platform.environment['HOME']?.trim() ??
      Platform.environment['USERPROFILE']?.trim();
  if (home != null && home.isNotEmpty) {
    return p.normalize(p.join(home, 'Downloads'));
  }

  return p.normalize(p.join(getAppDataDirectory().path, 'downloads'));
}

Future<String> getDefaultDownloadDirectory() async {
  return getDefaultDownloadDirectorySync();
}
