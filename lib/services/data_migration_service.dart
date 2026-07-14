import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/app_paths.dart';
import '../utils/logging.dart';

class DataMigrationService with Loggable {
  DataMigrationService({AppPaths? paths}) : _paths = paths ?? AppPaths.instance;

  final AppPaths _paths;

  Future<bool> migrateLegacyPortableData() async {
    if (await _paths.migrationMarker.exists()) {
      return false;
    }

    if (p.equals(
      p.normalize(_paths.supportDirectory.path),
      p.normalize(_paths.legacyPortableDirectory.path),
    )) {
      await _writeMarker();
      return false;
    }

    final legacy = _paths.legacyPortableDirectory;
    if (!await legacy.exists()) {
      await _writeMarker();
      return false;
    }

    final staging = Directory(
      p.join(
        _paths.supportDirectory.path,
        '.migration-v1-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await staging.create(recursive: true);

    try {
      await _copyIfTargetMissing(
        File(p.join(legacy.path, 'config', 'settings.json')),
        File(p.join(staging.path, 'config', 'settings.json')),
        stagingRoot: staging,
      );
      await _copyIfTargetMissing(
        File(p.join(legacy.path, 'config', 'aria2_instances.json')),
        File(p.join(staging.path, 'config', 'aria2_instances.json')),
        stagingRoot: staging,
      );
      for (final name in const <String>[
        'aria2.conf',
        'aria2.session',
        'aria2.log',
      ]) {
        await _copyIfTargetMissing(
          File(p.join(legacy.path, 'core', name)),
          File(p.join(staging.path, 'core', name)),
          stagingRoot: staging,
        );
      }

      await _validateJsonIfPresent(
        File(p.join(staging.path, 'config', 'settings.json')),
      );
      await _validateJsonIfPresent(
        File(p.join(staging.path, 'config', 'aria2_instances.json')),
      );
      await _mergeStaging(staging);
      await _writeMarker();
      i('Migrated legacy portable data to ${_paths.supportDirectory.path}');
      return true;
    } catch (error, stackTrace) {
      e('Legacy data migration failed', error: error, stackTrace: stackTrace);
      rethrow;
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  Future<void> _copyIfTargetMissing(
    File source,
    File stagingTarget, {
    required Directory stagingRoot,
  }) async {
    final finalTarget = File(
      p.join(
        _paths.supportDirectory.path,
        p.relative(stagingTarget.path, from: stagingRoot.path),
      ),
    );
    if (!await source.exists() || await finalTarget.exists()) {
      return;
    }
    await stagingTarget.parent.create(recursive: true);
    await source.copy(stagingTarget.path);
  }

  Future<void> _validateJsonIfPresent(File file) async {
    if (!await file.exists()) {
      return;
    }
    jsonDecode(await file.readAsString());
  }

  Future<void> _mergeStaging(Directory staging) async {
    await for (final entity in staging.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final relative = p.relative(entity.path, from: staging.path);
      final target = File(p.join(_paths.supportDirectory.path, relative));
      if (await target.exists()) {
        continue;
      }
      await target.parent.create(recursive: true);
      await entity.rename(target.path);
    }
  }

  Future<void> _writeMarker() async {
    await _paths.migrationMarker.writeAsString(
      DateTime.now().toUtc().toIso8601String(),
      flush: true,
    );
  }
}
