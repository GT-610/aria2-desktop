import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:aria2_desktop/models/aria2_instance.dart';
import 'package:aria2_desktop/pages/download_page/enums.dart';
import 'package:aria2_desktop/pages/download_page/models/download_task.dart';
import 'package:aria2_desktop/pages/download_page/services/download_task_service.dart';
import 'package:aria2_desktop/services/aria2_rpc_client.dart';

void main() {
  group('DownloadTaskService path safety', () {
    test('rejects traversal paths when checking base directory', () {
      final tempRoot = Directory.systemTemp.createTempSync(
        'download-task-service-',
      );
      addTearDown(() => tempRoot.deleteSync(recursive: true));

      final baseDir = p.join(tempRoot.path, 'base', 'dir');
      final escapedPath = p.join(baseDir, '..', '..', 'etc', 'passwd');
      final safePath = p.join(baseDir, 'child', 'file.txt');

      expect(
        DownloadTaskService.isWithinBaseDirectoryForTesting(
          escapedPath,
          baseDir,
        ),
        isFalse,
      );
      expect(
        DownloadTaskService.isWithinBaseDirectoryForTesting(safePath, baseDir),
        isTrue,
      );
    });

    test(
      'skips deleting targets that resolve outside the base directory',
      () async {
        final tempRoot = await Directory.systemTemp.createTemp(
          'download-task-service-',
        );
        addTearDown(() => tempRoot.deleteSync(recursive: true));

        final baseDir = Directory(p.join(tempRoot.path, 'base'))..createSync();
        final outsideDir = Directory(p.join(tempRoot.path, 'outside'))
          ..createSync();
        final outsideFile = File(p.join(outsideDir.path, 'escape.txt'))
          ..writeAsStringSync('keep me');

        final task = DownloadTask(
          id: 'task-1',
          name: 'ignored',
          status: DownloadStatus.stopped,
          progress: 0,
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          size: '0 B',
          completedSize: '0 B',
          isLocal: true,
          instanceId: 'local',
          dir: baseDir.path,
          files: [
            {'path': p.join(baseDir.path, '..', 'outside', 'escape.txt')},
          ],
        );

        final errors =
            await DownloadTaskService.deleteDownloadedFilesForTesting(task);

        expect(outsideFile.existsSync(), isTrue);
        expect(
          errors.any(
            (error) => error.contains('Skipped path outside base directory'),
          ),
          isTrue,
        );
      },
    );
  });

  group('DownloadTaskService deleteTaskWithClient', () {
    test(
      'returns partial success when Aria2 removal succeeds but file cleanup fails',
      () async {
        var removed = false;

        final task = DownloadTask(
          id: 'task-2',
          name: 'file.zip',
          status: DownloadStatus.active,
          progress: 0,
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          size: '0 B',
          completedSize: '0 B',
          isLocal: true,
          instanceId: 'local',
          dir: Directory.systemTemp.path,
        );

        final client = Aria2RpcClient(
          Aria2Instance(
            id: 'local',
            name: 'Local',
            type: InstanceType.remote,
            protocol: 'http',
            host: '127.0.0.1',
            port: 6800,
          ),
        );

        final result = await DownloadTaskService.deleteTaskWithClient(
          client,
          task,
          deleteDownloadedFiles: true,
          removeTaskOverride: () async {
            removed = true;
          },
          deleteFilesOverride: (_) async {
            throw FileSystemException('cleanup failed');
          },
        );

        expect(removed, isTrue);
        expect(result.removedFromAria2, isTrue);
        expect(result.hasFileDeletionErrors, isTrue);
        expect(result.fileDeletionErrors.single, contains('cleanup failed'));
        client.close();
      },
    );
  });
}
