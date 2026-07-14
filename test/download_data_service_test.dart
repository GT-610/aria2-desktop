import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/models/aria2_instance.dart';
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

  test('keeps stale tasks when one connected instance refresh fails', () async {
    Future<HttpServer> startServer(String gid) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'jsonrpc': '2.0',
            'id': decoded['id'],
            'result': <Object>[
              <Object>[
                <Object>[
                  <String, String>{
                    'gid': gid,
                    'status': 'active',
                    'totalLength': '10',
                    'completedLength': '1',
                    'downloadSpeed': '1',
                    'uploadSpeed': '0',
                  },
                ],
              ],
              <Object>[<Object>[]],
              <Object>[<Object>[]],
            ],
          }),
        );
        await request.response.close();
      });
      return server;
    }

    final firstServer = await startServer('first');
    final secondServer = await startServer('second');
    final instances = <Aria2Instance>[
      Aria2Instance(
        id: 'one',
        name: 'One',
        type: InstanceType.remote,
        protocol: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: firstServer.port,
        status: ConnectionStatus.connected,
      ),
      Aria2Instance(
        id: 'two',
        name: 'Two',
        type: InstanceType.remote,
        protocol: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: secondServer.port,
        status: ConnectionStatus.connected,
      ),
    ];
    final service = DownloadDataService();

    await service.refreshTasks(instances);
    expect(
      service.tasks.map((task) => task.id),
      containsAll(<String>['first', 'second']),
    );

    await secondServer.close(force: true);
    await service.refreshTasks(instances);

    expect(
      service.tasks.map((task) => task.id),
      containsAll(<String>['first', 'second']),
    );
    expect(service.instanceStates['two']?.isStale, isTrue);
    expect(service.instanceStates['one']?.isStale, isFalse);

    service.dispose();
    await firstServer.close(force: true);
  });
}
