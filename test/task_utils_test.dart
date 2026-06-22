import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';
import 'package:setsuna/pages/download_page/utils/task_utils.dart';

void main() {
  group('TaskUtils', () {
    group('calculateRemainingTime', () {
      test('returns placeholder when total bytes is zero', () {
        final task = DownloadTask(
          id: 't1',
          name: 'test',
          status: DownloadStatus.active,
          progress: 0,
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          size: '0 B',
          completedSize: '0 B',
          isLocal: true,
          instanceId: 'inst-1',
          totalLengthBytes: 0,
          completedLengthBytes: 0,
          downloadSpeedBytes: 100,
        );

        expect(TaskUtils.calculateRemainingTime(task), '--');
      });

      test('returns 0s when completed', () {
        final task = DownloadTask(
          id: 't1',
          name: 'test',
          status: DownloadStatus.active,
          progress: 1.0,
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          size: '1.00 KB',
          completedSize: '1.00 KB',
          isLocal: true,
          instanceId: 'inst-1',
          totalLengthBytes: 1024,
          completedLengthBytes: 1024,
          downloadSpeedBytes: 100,
        );

        expect(TaskUtils.calculateRemainingTime(task), '0s');
      });

      test('calculates remaining time correctly', () {
        final task = DownloadTask(
          id: 't1',
          name: 'test',
          status: DownloadStatus.active,
          progress: 0.5,
          downloadSpeed: '100 B/s',
          uploadSpeed: '0 B/s',
          size: '1000 B',
          completedSize: '500 B',
          isLocal: true,
          instanceId: 'inst-1',
          totalLengthBytes: 1000,
          completedLengthBytes: 500,
          downloadSpeedBytes: 100,
        );

        expect(TaskUtils.calculateRemainingTime(task), '5s');
      });

      test('returns placeholder when speed is zero', () {
        final task = DownloadTask(
          id: 't1',
          name: 'test',
          status: DownloadStatus.active,
          progress: 0.5,
          downloadSpeed: '0 B/s',
          uploadSpeed: '0 B/s',
          size: '1000 B',
          completedSize: '500 B',
          isLocal: true,
          instanceId: 'inst-1',
          totalLengthBytes: 1000,
          completedLengthBytes: 500,
          downloadSpeedBytes: 0,
        );

        expect(TaskUtils.calculateRemainingTime(task), '--');
      });
    });
  });
}
