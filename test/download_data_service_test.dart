import 'dart:async';
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

  test(
    'clears tasks and instance state when all instances disconnect',
    () async {
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
                    'gid': 'connected',
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
      final instance = Aria2Instance(
        id: 'disconnect',
        name: 'Disconnect',
        type: InstanceType.remote,
        protocol: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        status: ConnectionStatus.connected,
      );
      final service = DownloadDataService();

      await service.refreshTasks(<Aria2Instance>[instance]);
      expect(service.tasks.single.id, 'connected');
      expect(service.instanceStates, contains(instance.id));

      await service.refreshTasks(const <Aria2Instance>[]);

      expect(service.tasks, isEmpty);
      expect(service.instanceStates, isEmpty);
      service.dispose();
      await server.close(force: true);
    },
  );

  test('keeps stale tasks when a multicall item fails', () async {
    var failWaitingCall = false;
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
                  'gid': 'kept',
                  'status': 'active',
                  'totalLength': '10',
                  'completedLength': '1',
                  'downloadSpeed': '1',
                  'uploadSpeed': '0',
                },
              ],
            ],
            if (failWaitingCall)
              <String, Object>{'code': 1, 'message': 'waiting failed'}
            else
              <Object>[<Object>[]],
            <Object>[<Object>[]],
          ],
        }),
      );
      await request.response.close();
    });
    final instance = Aria2Instance(
      id: 'partial',
      name: 'Partial',
      type: InstanceType.remote,
      protocol: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      status: ConnectionStatus.connected,
    );
    final service = DownloadDataService();

    await service.refreshTasks(<Aria2Instance>[instance]);
    expect(service.tasks.single.id, 'kept');

    failWaitingCall = true;
    await service.refreshTasks(<Aria2Instance>[instance]);

    expect(service.tasks.single.id, 'kept');
    expect(service.instanceStates['partial']?.isStale, isTrue);
    service.dispose();
    await server.close(force: true);
  });

  test('queues one latest refresh while a refresh is in progress', () async {
    final firstRequestSeen = Completer<void>();
    final releaseFirstRequest = Completer<void>();
    var requestCount = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requestCount++;
      final requestNumber = requestCount;
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (requestNumber == 1) {
        firstRequestSeen.complete();
        await releaseFirstRequest.future;
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': decoded['id'],
          'result': <Object>[
            <Object>[<Object>[]],
            <Object>[<Object>[]],
            <Object>[<Object>[]],
          ],
        }),
      );
      await request.response.close();
    });
    final instance = Aria2Instance(
      id: 'queue',
      name: 'Queue',
      type: InstanceType.remote,
      protocol: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      status: ConnectionStatus.connected,
    );
    final service = DownloadDataService();

    final firstRefresh = service.refreshTasks(<Aria2Instance>[instance]);
    await firstRequestSeen.future;
    final queuedRefresh = service.refreshTasks(<Aria2Instance>[instance]);
    releaseFirstRequest.complete();
    await Future.wait(<Future<void>>[firstRefresh, queuedRefresh]);

    // Two-phase polling: the cold first refresh performs a basic poll plus a
    // detailed re-fetch; the coalesced second refresh hits the
    // "nothing changed" fast path and only polls basic fields.
    expect(requestCount, 3);
    service.dispose();
    await server.close(force: true);
  });

  test('does not publish an in-flight refresh after disposal', () async {
    final requestSeen = Completer<void>();
    final releaseRequest = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      requestSeen.complete();
      await releaseRequest.future;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': decoded['id'],
          'result': <Object>[
            <Object>[
              <Object>[
                <String, String>{
                  'gid': 'late',
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
    final instance = Aria2Instance(
      id: 'dispose',
      name: 'Dispose',
      type: InstanceType.remote,
      protocol: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      status: ConnectionStatus.connected,
    );
    final service = DownloadDataService();
    var notificationCount = 0;
    service.addListener(() => notificationCount++);

    final refresh = service.refreshTasks(<Aria2Instance>[instance]);
    await requestSeen.future;
    service.dispose();
    releaseRequest.complete();
    await refresh;

    expect(notificationCount, 0);
    expect(service.tasks, isEmpty);
    await server.close(force: true);
  });

  test('refreshes tasks when aria2 sends a websocket notification', () async {
    WebSocket? socket;
    var gid = 'initial';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      socket = await WebSocketTransformer.upgrade(request);
      socket!.listen((message) {
        final decoded = jsonDecode(message as String) as Map<String, dynamic>;
        socket!.add(
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
      });
    });
    final instance = Aria2Instance(
      id: 'events',
      name: 'Events',
      type: InstanceType.remote,
      protocol: 'ws',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      status: ConnectionStatus.connected,
    );
    final service = DownloadDataService();
    // Install the provider used by RPC notifications without leaving the
    // periodic refresh timer running during this test.
    service.startPeriodicRefresh(() => <Aria2Instance>[instance]);
    service.stopPeriodicRefresh();

    await service.refreshTasks(<Aria2Instance>[instance]);
    expect(service.tasks.single.id, 'initial');

    final refreshed = Completer<void>();
    service.addListener(() {
      if (service.tasks.any((task) => task.id == 'updated') &&
          !refreshed.isCompleted) {
        refreshed.complete();
      }
    });
    gid = 'updated';
    socket!.add(
      jsonEncode(<String, dynamic>{
        'jsonrpc': '2.0',
        'method': 'aria2.onDownloadStart',
        'params': <Object>[
          <String, String>{'gid': gid},
        ],
      }),
    );

    await refreshed.future.timeout(const Duration(seconds: 2));
    expect(service.tasks.single.id, 'updated');
    service.dispose();
    await server.close(force: true);
  });

  test(
    'reuses detailed task objects while basic fields are unchanged',
    () async {
      var requestCount = 0;
      final fullTask = <String, dynamic>{
        'gid': 'bt-1',
        'status': 'active',
        'totalLength': '100',
        'completedLength': '10',
        'downloadSpeed': '5',
        'uploadSpeed': '1',
        'dir': '/downloads',
        'seeder': 'true',
        'numSeeders': '3',
        'infoHash': 'abc123',
        'bittorrent': <String, dynamic>{
          'info': <String, dynamic>{'name': 'Ubuntu ISO'},
        },
        'files': <Object>[
          <String, String>{
            'index': '1',
            'path': '/downloads/ubuntu.iso',
            'length': '100',
            'completedLength': '10',
            'selected': 'true',
          },
        ],
      };
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requestCount++;
        final body = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'jsonrpc': '2.0',
            'id': decoded['id'],
            'result': <Object>[
              <Object>[fullTask],
              <Object>[<Object>[]],
              <Object>[<Object>[]],
            ],
          }),
        );
        await request.response.close();
      });
      final instance = Aria2Instance(
        id: 'stable',
        name: 'Stable',
        type: InstanceType.remote,
        protocol: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        status: ConnectionStatus.connected,
      );
      final service = DownloadDataService();

      // Cold refresh: basic poll (no bittorrent data) + detailed re-fetch.
      await service.refreshTasks(<Aria2Instance>[instance]);
      expect(service.tasks.single.name, 'Ubuntu ISO');
      expect(requestCount, 2);

      // Warm refresh with identical basic fields: only the cheap poll runs and
      // the previously detailed task objects are published unchanged.
      final before = service.tasks.single;
      await service.refreshTasks(<Aria2Instance>[instance]);
      expect(requestCount, 3);
      expect(service.tasks.single.name, 'Ubuntu ISO');
      expect(identical(service.tasks.single, before), isTrue);

      service.dispose();
      await server.close(force: true);
    },
  );

  test('aggregates global stats reported by connected instances', () async {
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
            <Object>[<Object>[]],
            <Object>[<Object>[]],
            <Object>[<Object>[]],
            <Object>[
              <String, String>{
                'downloadSpeed': '2048',
                'uploadSpeed': '512',
                'numActive': '2',
                'numWaiting': '3',
                'numStopped': '4',
              },
            ],
          ],
        }),
      );
      await request.response.close();
    });
    final instance = Aria2Instance(
      id: 'stats',
      name: 'Stats',
      type: InstanceType.remote,
      protocol: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      status: ConnectionStatus.connected,
    );
    final service = DownloadDataService();

    expect(service.aggregatedGlobalSpeeds, isNull);

    await service.refreshTasks(<Aria2Instance>[instance]);

    expect(service.aggregatedGlobalSpeeds, (
      downloadSpeed: 2048,
      uploadSpeed: 512,
    ));
    service.dispose();
    await server.close(force: true);
  });
}
