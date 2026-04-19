import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/utils/task_parser.dart';

void main() {
  group('TaskParser', () {
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
  });
}
