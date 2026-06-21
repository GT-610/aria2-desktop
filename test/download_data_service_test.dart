import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/services/download_data_service.dart';

void main() {
  group('DownloadTaskNotification', () {
    group('constructor', () {
      test('stores all required fields', () {
        const notification = DownloadTaskNotification(
          taskId: 'gid-123',
          taskName: 'file.zip',
          instanceId: 'inst-1',
          type: DownloadTaskNotificationType.completed,
        );

        expect(notification.taskId, 'gid-123');
        expect(notification.taskName, 'file.zip');
        expect(notification.instanceId, 'inst-1');
        expect(notification.type, DownloadTaskNotificationType.completed);
        expect(notification.errorMessage, isNull);
      });

      test('stores optional errorMessage', () {
        const notification = DownloadTaskNotification(
          taskId: 'gid-456',
          taskName: 'broken.zip',
          instanceId: 'inst-2',
          type: DownloadTaskNotificationType.failed,
          errorMessage: 'Connection refused',
        );

        expect(notification.errorMessage, 'Connection refused');
      });
    });

    group('DownloadTaskNotificationType', () {
      test('has two values', () {
        expect(DownloadTaskNotificationType.values.length, 2);
      });

      test('contains completed and failed', () {
        expect(
          DownloadTaskNotificationType.values,
          contains(DownloadTaskNotificationType.completed),
        );
        expect(
          DownloadTaskNotificationType.values,
          contains(DownloadTaskNotificationType.failed),
        );
      });
    });
  });

  group('DownloadDataService', () {
    test('tasks is empty before initialization', () {
      final service = DownloadDataService();
      expect(service.tasks, isEmpty);
    });

    test('isRefreshing is false before initialization', () {
      final service = DownloadDataService();
      expect(service.isRefreshing, isFalse);
    });

    test('lastError is null before initialization', () {
      final service = DownloadDataService();
      expect(service.lastError, isNull);
    });

    test('tasksVersion starts at zero', () {
      final service = DownloadDataService();
      expect(service.tasksVersion, 0);
    });

    test('takePendingNotifications returns empty list initially', () {
      final service = DownloadDataService();
      expect(service.takePendingNotifications(), isEmpty);
    });

    test('stopPeriodicRefresh does not throw', () {
      final service = DownloadDataService();
      expect(() => service.stopPeriodicRefresh(), returnsNormally);
    });

    test('dispose does not throw', () {
      final service = DownloadDataService();
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
