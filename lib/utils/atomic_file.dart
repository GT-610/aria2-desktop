import 'dart:io';

import 'package:path/path.dart' as p;

class AtomicFile {
  const AtomicFile._();

  static final Map<String, Future<void>> _writeTails = <String, Future<void>>{};

  static Future<void> recover(File target) async {
    if (await target.exists()) {
      return;
    }
    final backup = File('${target.path}.bak');
    if (await backup.exists()) {
      await backup.rename(target.path);
    }
  }

  static Future<void> writeString(File target, String contents) async {
    final key = p.normalize(p.absolute(target.path));
    final previous = _writeTails[key] ?? Future<void>.value();
    final operation = previous.then(
      (_) => _writeStringUnlocked(target, contents),
      onError: (_, _) => _writeStringUnlocked(target, contents),
    );
    late final Future<void> tracked;
    tracked = operation.whenComplete(() {
      if (identical(_writeTails[key], tracked)) {
        _writeTails.remove(key);
      }
    });
    _writeTails[key] = tracked;
    return tracked;
  }

  static Future<void> _writeStringUnlocked(File target, String contents) async {
    await recover(target);
    await target.parent.create(recursive: true);
    final temporary = File(
      p.join(
        target.parent.path,
        '.${p.basename(target.path)}.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );

    try {
      await temporary.writeAsString(contents, flush: true);
      if (await target.exists()) {
        final backup = File('${target.path}.bak');
        if (await backup.exists()) {
          await backup.delete();
        }
        await target.rename(backup.path);
        try {
          await temporary.rename(target.path);
        } catch (_) {
          if (!await target.exists() && await backup.exists()) {
            await backup.rename(target.path);
          }
          rethrow;
        }
        try {
          await backup.delete();
        } on FileSystemException {
          // The primary swap succeeded. A stale backup is safe to clean up on
          // the next write and must not turn a successful write into a failure.
        }
      } else {
        await temporary.rename(target.path);
      }
    } finally {
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } on FileSystemException {
          // Best-effort cleanup must not mask the original write result.
        }
      }
    }
  }
}
