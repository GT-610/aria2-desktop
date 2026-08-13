import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';
import 'package:setsuna/services/power_management_service.dart';

DownloadTask _task({
  required DownloadStatus status,
  String? taskStatus,
  bool isSeeder = false,
}) {
  return DownloadTask(
    id: 'task',
    name: 'task',
    status: status,
    taskStatus: taskStatus,
    progress: 0,
    downloadSpeed: '0 B/s',
    uploadSpeed: '0 B/s',
    size: '0 B',
    completedSize: '0 B',
    isLocal: true,
    instanceId: 'builtin',
    isSeeder: isSeeder,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('setsuna/power_management_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('only prevents sleep for active non-seeding downloads', () {
    expect(
      shouldPreventSystemSleep(
        enabled: true,
        tasks: <DownloadTask>[
          _task(status: DownloadStatus.active, taskStatus: 'active'),
        ],
      ),
      isTrue,
    );
    expect(
      shouldPreventSystemSleep(
        enabled: true,
        tasks: <DownloadTask>[
          _task(
            status: DownloadStatus.active,
            taskStatus: 'active',
            isSeeder: true,
          ),
          _task(status: DownloadStatus.waiting, taskStatus: 'paused'),
        ],
      ),
      isFalse,
    );
    expect(
      shouldPreventSystemSleep(
        enabled: false,
        tasks: <DownloadTask>[
          _task(status: DownloadStatus.active, taskStatus: 'active'),
        ],
      ),
      isFalse,
    );
  });

  test('serializes platform calls and applies the latest state', () async {
    final firstCall = Completer<void>();
    final releaseFirstCall = Completer<void>();
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (!firstCall.isCompleted) {
        firstCall.complete();
        await releaseFirstCall.future;
      }
      return null;
    });
    final service = PowerManagementService(
      channel: channel,
      isSupported: true,
      isLinux: false,
    );

    final acquire = service.synchronize(
      enabled: true,
      tasks: <DownloadTask>[
        _task(status: DownloadStatus.active, taskStatus: 'active'),
      ],
    );
    await firstCall.future;
    final release = service.release();
    releaseFirstCall.complete();
    await Future.wait(<Future<void>>[acquire, release]);

    expect(calls.map((call) => call.arguments), <Object?>[
      <String, Object>{'enabled': true},
      <String, Object>{'enabled': false},
    ]);
  });

  test('continues updating after an unchanged synchronization', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    final service = PowerManagementService(
      channel: channel,
      isSupported: true,
      isLinux: false,
    );
    final activeTasks = <DownloadTask>[
      _task(status: DownloadStatus.active, taskStatus: 'active'),
    ];

    await service.synchronize(enabled: true, tasks: activeTasks);
    await service.synchronize(enabled: true, tasks: activeTasks);
    await service.release();

    expect(calls.map((call) => call.arguments), <Object?>[
      <String, Object>{'enabled': true},
      <String, Object>{'enabled': false},
    ]);
  });

  test('does not call unsupported platform integrations', () async {
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });
    final service = PowerManagementService(
      channel: channel,
      isSupported: false,
      isLinux: false,
    );

    await service.release();

    expect(called, isFalse);
  });
}
