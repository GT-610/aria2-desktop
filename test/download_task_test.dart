import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';

void main() {
  group('DownloadTask', () {
    group('key', () {
      test('returns instanceId::id', () {
        final task = DownloadTask(
          id: 'task-123',
          name: 'file.zip',
          status: DownloadStatus.active,
          progress: 0.5,
          downloadSpeed: '100 KB/s',
          uploadSpeed: '10 KB/s',
          size: '1.00 GB',
          completedSize: '500.00 MB',
          isLocal: true,
          instanceId: 'inst-1',
        );

        expect(task.key, 'inst-1::task-123');
      });

      test('different instances produce different keys', () {
        final task1 = DownloadTask(
          id: 'task-1',
          name: 'file.zip',
          status: DownloadStatus.active,
          progress: 0,
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          size: '0 B',
          completedSize: '0 B',
          isLocal: true,
          instanceId: 'inst-1',
        );

        final task2 = DownloadTask(
          id: 'task-1',
          name: 'file.zip',
          status: DownloadStatus.active,
          progress: 0,
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          size: '0 B',
          completedSize: '0 B',
          isLocal: true,
          instanceId: 'inst-2',
        );

        expect(task1.key, isNot(task2.key));
      });
    });

    group('default values', () {
      test('has correct defaults for optional fields', () {
        final task = DownloadTask(
          id: 'task-1',
          name: 'file.zip',
          status: DownloadStatus.active,
          progress: 0,
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          size: '0 B',
          completedSize: '0 B',
          isLocal: true,
          instanceId: 'inst-1',
        );

        expect(task.taskStatus, isNull);
        expect(task.connections, isNull);
        expect(task.numSeeders, isNull);
        expect(task.dir, isNull);
        expect(task.totalLengthBytes, 0);
        expect(task.completedLengthBytes, 0);
        expect(task.uploadLengthBytes, 0);
        expect(task.downloadSpeedBytes, 0);
        expect(task.uploadSpeedBytes, 0);
        expect(task.files, isNull);
        expect(task.bittorrentInfo, isNull);
        expect(task.trackers, isNull);
        expect(task.uris, isNull);
        expect(task.errorMessage, isNull);
        expect(task.startTime, isNull);
        expect(task.bitfield, isNull);
        expect(task.infoHash, isNull);
        expect(task.pieceLength, isNull);
        expect(task.numPieces, isNull);
        expect(task.isSeeder, isFalse);
      });
    });

    group('constructor', () {
      test('stores all required fields', () {
        final task = DownloadTask(
          id: 'gid-123',
          name: 'Ubuntu.iso',
          status: DownloadStatus.waiting,
          taskStatus: 'paused',
          progress: 0.75,
          downloadSpeed: '5.00 MB/s',
          uploadSpeed: '1.00 MB/s',
          size: '4.00 GB',
          completedSize: '3.00 GB',
          isLocal: false,
          instanceId: 'remote-1',
          connections: 16,
          numSeeders: 50,
          dir: '/downloads',
          totalLengthBytes: 4294967296,
          completedLengthBytes: 3221225472,
          uploadLengthBytes: 104857600,
          downloadSpeedBytes: 5242880,
          uploadSpeedBytes: 1048576,
          errorMessage: null,
          isSeeder: true,
        );

        expect(task.id, 'gid-123');
        expect(task.name, 'Ubuntu.iso');
        expect(task.status, DownloadStatus.waiting);
        expect(task.taskStatus, 'paused');
        expect(task.progress, 0.75);
        expect(task.downloadSpeed, '5.00 MB/s');
        expect(task.uploadSpeed, '1.00 MB/s');
        expect(task.size, '4.00 GB');
        expect(task.completedSize, '3.00 GB');
        expect(task.isLocal, isFalse);
        expect(task.instanceId, 'remote-1');
        expect(task.connections, 16);
        expect(task.numSeeders, 50);
        expect(task.dir, '/downloads');
        expect(task.totalLengthBytes, 4294967296);
        expect(task.completedLengthBytes, 3221225472);
        expect(task.uploadLengthBytes, 104857600);
        expect(task.downloadSpeedBytes, 5242880);
        expect(task.uploadSpeedBytes, 1048576);
        expect(task.isSeeder, isTrue);
      });
    });
  });

  group('DownloadStatus', () {
    test('has three values', () {
      expect(DownloadStatus.values.length, 3);
    });

    test('contains active, waiting, stopped', () {
      expect(DownloadStatus.values, contains(DownloadStatus.active));
      expect(DownloadStatus.values, contains(DownloadStatus.waiting));
      expect(DownloadStatus.values, contains(DownloadStatus.stopped));
    });
  });

  group('CategoryType', () {
    test('has four values', () {
      expect(CategoryType.values.length, 4);
    });
  });

  group('FilterOption', () {
    test('has seven values', () {
      expect(FilterOption.values.length, 7);
    });
  });

  group('TaskSortOption', () {
    test('has five values', () {
      expect(TaskSortOption.values.length, 5);
    });
  });
}
