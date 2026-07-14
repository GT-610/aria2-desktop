import 'dart:io';

import 'package:path/path.dart' as p;

class AtomicFile {
  const AtomicFile._();

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
          await backup.delete();
        } catch (_) {
          if (!await target.exists() && await backup.exists()) {
            await backup.rename(target.path);
          }
          rethrow;
        }
      } else {
        await temporary.rename(target.path);
      }
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
