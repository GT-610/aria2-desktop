import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_branding.dart';

class AppPaths {
  AppPaths._({
    required this.supportDirectory,
    required this.legacyPortableDirectory,
    required this.bundledCoreDirectory,
  });

  static AppPaths? _instance;

  final Directory supportDirectory;
  final Directory legacyPortableDirectory;
  final Directory bundledCoreDirectory;

  Directory get configDirectory =>
      Directory(p.join(supportDirectory.path, 'config'));
  Directory get coreDirectory =>
      Directory(p.join(supportDirectory.path, 'core'));
  Directory get logDirectory =>
      Directory(p.join(supportDirectory.path, 'logs'));
  File get migrationMarker =>
      File(p.join(supportDirectory.path, '.migration-v1-complete'));

  static AppPaths get instance {
    final value = _instance;
    if (value != null) {
      return value;
    }
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final portableDirectory = Directory(
      p.join(executableDirectory.path, 'data'),
    );
    return _instance = AppPaths._(
      supportDirectory: portableDirectory,
      legacyPortableDirectory: portableDirectory,
      bundledCoreDirectory: bundledCoreDirectoryFor(
        executableDirectory: executableDirectory,
        isMacOS: Platform.isMacOS,
      ),
    );
  }

  static Future<AppPaths> initialize() async {
    final existing = _instance;
    if (existing != null) {
      return existing;
    }

    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final legacyPortableDirectory = Directory(
      p.join(executableDirectory.path, 'data'),
    );
    final platformSupportDirectory = await getApplicationSupportDirectory();
    final supportDirectory = Platform.isLinux
        ? Directory(p.join(platformSupportDirectory.path, kAppPackageName))
        : platformSupportDirectory;

    final paths = AppPaths._(
      supportDirectory: supportDirectory,
      legacyPortableDirectory: legacyPortableDirectory,
      bundledCoreDirectory: bundledCoreDirectoryFor(
        executableDirectory: executableDirectory,
        isMacOS: Platform.isMacOS,
      ),
    );
    await paths.ensureDirectories();
    _instance = paths;
    return paths;
  }

  Future<void> ensureDirectories() async {
    for (final directory in <Directory>[
      supportDirectory,
      configDirectory,
      coreDirectory,
      logDirectory,
    ]) {
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }

  static void setForTesting(AppPaths paths) {
    _instance = paths;
  }

  static Directory bundledCoreDirectoryFor({
    required Directory executableDirectory,
    required bool isMacOS,
  }) {
    final dataDirectory = isMacOS
        ? p.join(executableDirectory.path, '..', 'Resources', 'data')
        : p.join(executableDirectory.path, 'data');
    return Directory(p.normalize(p.join(dataDirectory, 'core')));
  }

  static AppPaths testing({
    required Directory supportDirectory,
    required Directory legacyPortableDirectory,
    Directory? bundledCoreDirectory,
  }) {
    return AppPaths._(
      supportDirectory: supportDirectory,
      legacyPortableDirectory: legacyPortableDirectory,
      bundledCoreDirectory:
          bundledCoreDirectory ??
          Directory(p.join(legacyPortableDirectory.path, 'core')),
    );
  }
}
