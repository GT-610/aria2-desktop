import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/utils/task_parser.dart';

void main() {
  group('TaskParser', () {
    group('getDownloadStatus', () {
      test('returns waiting for null', () {
        expect(TaskParser.getDownloadStatus(null), DownloadStatus.waiting);
      });

      test('maps active to active', () {
        expect(TaskParser.getDownloadStatus('active'), DownloadStatus.active);
      });

      test('maps waiting to waiting', () {
        expect(TaskParser.getDownloadStatus('waiting'), DownloadStatus.waiting);
      });

      test('maps paused to waiting', () {
        expect(TaskParser.getDownloadStatus('paused'), DownloadStatus.waiting);
      });

      test('maps complete to stopped', () {
        expect(
          TaskParser.getDownloadStatus('complete'),
          DownloadStatus.stopped,
        );
      });

      test('maps error to stopped', () {
        expect(TaskParser.getDownloadStatus('error'), DownloadStatus.stopped);
      });

      test('maps removed to stopped', () {
        expect(TaskParser.getDownloadStatus('removed'), DownloadStatus.stopped);
      });

      test('returns waiting for unknown status', () {
        expect(TaskParser.getDownloadStatus('unknown'), DownloadStatus.waiting);
      });
    });

    group('parseTask', () {
      test('prefers bittorrent info name over first file path', () {
        final task = TaskParser.parseTask(
          {
            'gid': '1234567890abcdef',
            'status': 'active',
            'totalLength': '100',
            'completedLength': '50',
            'downloadSpeed': '10',
            'uploadSpeed': '0',
            'files': [
              {
                'path': '/downloads/fallback-name.iso',
                'uris': [
                  {'uri': 'https://example.com/fallback-name.iso'},
                ],
              },
            ],
            'bittorrent': {
              'info': {'name': 'Ubuntu ISO'},
              'announceList': [
                ['https://tracker.example/announce'],
              ],
            },
          },
          'instance-1',
          true,
        );

        expect(task.name, 'Ubuntu ISO');
        expect(task.trackers, ['https://tracker.example/announce']);
        expect(task.uris, ['https://example.com/fallback-name.iso']);
        expect(task.status, DownloadStatus.active);
      });

      test('parses timestamps into local datetimes when provided', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'abcdef',
            'status': 'complete',
            'totalLength': '100',
            'completedLength': '100',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'completedAt': '1710000000',
          },
          'instance-1',
          false,
        );

        expect(task.startTime, isNotNull);
        expect(task.startTime!.millisecondsSinceEpoch, 1710000000 * 1000);
      });

      test('uses gid as name when no file name available', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid123456789',
            'status': 'active',
            'totalLength': '0',
            'completedLength': '0',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'files': <Map<String, dynamic>>[],
          },
          'instance-1',
          true,
        );

        expect(task.name, 'gid12345');
      });

      test('uses full gid as name when shorter than 8 chars', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'short',
            'status': 'active',
            'totalLength': '0',
            'completedLength': '0',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'files': <Map<String, dynamic>>[],
          },
          'instance-1',
          true,
        );

        expect(task.name, 'short');
      });

      test('calculates progress correctly', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid-1',
            'status': 'active',
            'totalLength': '200',
            'completedLength': '50',
            'downloadSpeed': '10',
            'uploadSpeed': '0',
            'files': <Map<String, dynamic>>[],
          },
          'instance-1',
          true,
        );

        expect(task.progress, 0.25);
        expect(task.totalLengthBytes, 200);
        expect(task.completedLengthBytes, 50);
      });

      test('returns zero progress when totalLength is zero', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid-1',
            'status': 'active',
            'totalLength': '0',
            'completedLength': '0',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'files': <Map<String, dynamic>>[],
          },
          'instance-1',
          true,
        );

        expect(task.progress, 0.0);
      });

      test('parses connections and numSeeders', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid-1',
            'status': 'active',
            'totalLength': '100',
            'completedLength': '0',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'connections': '5',
            'numSeeders': '10',
            'seeder': 'true',
            'files': <Map<String, dynamic>>[],
          },
          'instance-1',
          true,
        );

        expect(task.connections, 5);
        expect(task.numSeeders, 10);
        expect(task.isSeeder, isTrue);
      });

      test('parses dir field', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid-1',
            'status': 'active',
            'totalLength': '0',
            'completedLength': '0',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'dir': '/custom/downloads',
            'files': <Map<String, dynamic>>[],
          },
          'instance-1',
          true,
        );

        expect(task.dir, '/custom/downloads');
      });

      test('parses errorMessage', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid-1',
            'status': 'error',
            'totalLength': '100',
            'completedLength': '50',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'errorMessage': 'Connection refused',
            'files': <Map<String, dynamic>>[],
          },
          'instance-1',
          true,
        );

        expect(task.errorMessage, 'Connection refused');
      });

      test('parses bitfield and infoHash', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid-1',
            'status': 'active',
            'totalLength': '100',
            'completedLength': '50',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'bitfield': 'ffff',
            'infoHash': 'abc123',
            'pieceLength': '262144',
            'numPieces': '100',
            'files': <Map<String, dynamic>>[],
          },
          'instance-1',
          true,
        );

        expect(task.bitfield, 'ffff');
        expect(task.infoHash, 'abc123');
        expect(task.pieceLength, 262144);
        expect(task.numPieces, 100);
      });

      test('extracts file name from file path', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid-1',
            'status': 'active',
            'totalLength': '0',
            'completedLength': '0',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'files': [
              {
                'path': '/downloads/documents/report.pdf',
                'length': '1000',
                'completedLength': '500',
                'selected': 'true',
                'uris': <Map<String, dynamic>>[],
              },
            ],
          },
          'instance-1',
          true,
        );

        expect(task.name, 'report.pdf');
        expect(task.files, isNotNull);
        expect(task.files!.length, 1);
      });

      test('deduplicates URIs from multiple files', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid-1',
            'status': 'active',
            'totalLength': '0',
            'completedLength': '0',
            'downloadSpeed': '0',
            'uploadSpeed': '0',
            'files': [
              {
                'path': '/downloads/file1.zip',
                'length': '0',
                'completedLength': '0',
                'selected': 'true',
                'uris': [
                  {'uri': 'https://mirror1.com/file.zip'},
                  {'uri': 'https://mirror2.com/file.zip'},
                ],
              },
              {
                'path': '/downloads/file2.zip',
                'length': '0',
                'completedLength': '0',
                'selected': 'true',
                'uris': [
                  {'uri': 'https://mirror1.com/file.zip'},
                ],
              },
            ],
          },
          'instance-1',
          false,
        );

        expect(task.uris!.length, 2);
        expect(task.uris, contains('https://mirror1.com/file.zip'));
        expect(task.uris, contains('https://mirror2.com/file.zip'));
      });

      test('handles missing all optional fields gracefully', () {
        final task = TaskParser.parseTask(
          {
            'gid': 'gid-minimal',
            'status': 'active',
            'files': <Map<String, dynamic>>[],
          },
          'inst-1',
          true,
        );

        expect(task.id, 'gid-minimal');
        expect(task.totalLengthBytes, 0);
        expect(task.completedLengthBytes, 0);
        expect(task.downloadSpeedBytes, 0);
        expect(task.uploadSpeedBytes, 0);
        expect(task.connections, isNull);
        expect(task.numSeeders, isNull);
        expect(task.dir, isNull);
        expect(task.errorMessage, isNull);
        expect(task.bitfield, isNull);
        expect(task.infoHash, isNull);
      });
    });

    group('parseTasks', () {
      test('parses list of task maps', () {
        final tasks = TaskParser.parseTasks(
          [
            {
              'gid': 'gid-1',
              'status': 'active',
              'totalLength': '100',
              'completedLength': '0',
              'downloadSpeed': '0',
              'uploadSpeed': '0',
              'files': <Map<String, dynamic>>[],
            },
            {
              'gid': 'gid-2',
              'status': 'active',
              'totalLength': '200',
              'completedLength': '0',
              'downloadSpeed': '0',
              'uploadSpeed': '0',
              'files': <Map<String, dynamic>>[],
            },
          ],
          DownloadStatus.active,
          'inst-1',
          true,
        );

        expect(tasks.length, 2);
        expect(tasks[0].id, 'gid-1');
        expect(tasks[1].id, 'gid-2');
        expect(tasks[0].status, DownloadStatus.active);
      });

      test('handles nested list (multicall response)', () {
        final tasks = TaskParser.parseTasks(
          [
            [
              {
                'gid': 'gid-1',
                'status': 'active',
                'totalLength': '0',
                'completedLength': '0',
                'downloadSpeed': '0',
                'uploadSpeed': '0',
                'files': <Map<String, dynamic>>[],
              },
            ],
          ],
          DownloadStatus.active,
          'inst-1',
          true,
        );

        expect(tasks.length, 1);
        expect(tasks[0].id, 'gid-1');
      });

      test('skips non-map entries in task list', () {
        final tasks = TaskParser.parseTasks(
          [
            'not a map',
            42,
            {
              'gid': 'gid-valid',
              'status': 'active',
              'totalLength': '0',
              'completedLength': '0',
              'downloadSpeed': '0',
              'uploadSpeed': '0',
              'files': <Map<String, dynamic>>[],
            },
          ],
          DownloadStatus.active,
          'inst-1',
          true,
        );

        expect(tasks.length, 1);
        expect(tasks[0].id, 'gid-valid');
      });

      test('returns empty list for empty input', () {
        final tasks = TaskParser.parseTasks(
          [],
          DownloadStatus.active,
          'inst-1',
          true,
        );

        expect(tasks, isEmpty);
      });
    });
  });
}
