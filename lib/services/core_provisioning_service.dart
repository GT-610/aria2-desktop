import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../utils/app_paths.dart';
import '../utils/atomic_file.dart';

class CoreProvisioningService {
  CoreProvisioningService({AppPaths? paths})
    : _paths = paths ?? AppPaths.instance;

  final AppPaths _paths;

  Future<void> ensureDefaultConfiguration() async {
    final target = File(p.join(_paths.coreDirectory.path, 'aria2.conf'));
    if (await target.exists()) {
      return;
    }
    final bundledFile = File(
      p.join(_paths.bundledCoreDirectory.path, 'aria2.conf'),
    );
    if (await bundledFile.exists()) {
      await target.parent.create(recursive: true);
      await bundledFile.copy(target.path);
      return;
    }
    final configuration = await rootBundle.loadString('assets/core/aria2.conf');
    await AtomicFile.writeString(target, configuration);
  }
}
