import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../utils/app_paths.dart';
import '../utils/atomic_file.dart';

class CoreProvisioningException implements Exception {
  const CoreProvisioningException(this.message, this.cause);

  final String message;
  final Object cause;

  @override
  String toString() => '$message: $cause';
}

class CoreProvisioningService {
  CoreProvisioningService({AppPaths? paths})
    : _paths = paths ?? AppPaths.instance;

  final AppPaths _paths;

  Future<void> ensureDefaultConfiguration() async {
    try {
      final target = File(p.join(_paths.coreDirectory.path, 'aria2.conf'));
      if (await target.exists()) {
        return;
      }
      final bundledFile = File(
        p.join(_paths.bundledCoreDirectory.path, 'aria2.conf'),
      );
      final configuration = await bundledFile.exists()
          ? await bundledFile.readAsString()
          : await rootBundle.loadString('assets/core/aria2.conf');
      await AtomicFile.writeString(target, configuration);
    } on FileSystemException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CoreProvisioningException(
          'Failed to write the built-in aria2 configuration',
          error,
        ),
        stackTrace,
      );
    } on FlutterError catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CoreProvisioningException(
          'Bundled aria2 configuration asset is unavailable',
          error,
        ),
        stackTrace,
      );
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CoreProvisioningException(
          'Failed to load the bundled aria2 configuration',
          error,
        ),
        stackTrace,
      );
    }
  }
}
