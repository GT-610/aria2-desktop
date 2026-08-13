import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';
import 'package:setsuna/services/desktop_progress_service.dart';

DownloadTask _task({
  required String id,
  required DownloadStatus status,
  String? taskStatus,
  int totalBytes = 0,
  int completedBytes = 0,
  bool isSeeder = false,
}) {
  return DownloadTask(
    id: id,
    name: id,
    status: status,
    taskStatus: taskStatus,
    progress: 0,
    downloadSpeed: '0 B/s',
    uploadSpeed: '0 B/s',
    size: '0 B',
    completedSize: '0 B',
    isLocal: true,
    instanceId: 'builtin',
    totalLengthBytes: totalBytes,
    completedLengthBytes: completedBytes,
    isSeeder: isSeeder,
  );
}

void main() {
  test('aggregates progress across active downloads', () {
    final progress = calculateDesktopProgress(
      enabled: true,
      tasks: <DownloadTask>[
        _task(
          id: 'one',
          status: DownloadStatus.active,
          taskStatus: 'active',
          totalBytes: 100,
          completedBytes: 25,
        ),
        _task(
          id: 'two',
          status: DownloadStatus.active,
          taskStatus: 'active',
          totalBytes: 300,
          completedBytes: 175,
        ),
        _task(
          id: 'paused',
          status: DownloadStatus.waiting,
          taskStatus: 'paused',
          totalBytes: 100,
          completedBytes: 90,
        ),
      ],
    );

    expect(progress, 0.5);
  });

  test('ignores seeding tasks and clears when no download is active', () {
    final progress = calculateDesktopProgress(
      enabled: true,
      tasks: <DownloadTask>[
        _task(
          id: 'seed',
          status: DownloadStatus.active,
          taskStatus: 'active',
          totalBytes: 100,
          completedBytes: 100,
          isSeeder: true,
        ),
      ],
    );

    expect(progress, -1);
  });

  test('uses indeterminate progress when active size is unknown', () {
    final progress = calculateDesktopProgress(
      enabled: true,
      tasks: <DownloadTask>[
        _task(
          id: 'metadata',
          status: DownloadStatus.active,
          taskStatus: 'active',
        ),
      ],
    );

    expect(progress, greaterThan(1));
  });

  test(
    'serializes updates and applies the latest requested progress',
    () async {
      final firstCall = Completer<void>();
      final releaseFirstCall = Completer<void>();
      final applied = <double>[];
      final service = DesktopProgressService(
        isSupported: true,
        setProgress: (progress) async {
          applied.add(progress);
          if (!firstCall.isCompleted) {
            firstCall.complete();
            await releaseFirstCall.future;
          }
        },
      );

      final first = service.synchronize(
        enabled: true,
        tasks: <DownloadTask>[
          _task(
            id: 'one',
            status: DownloadStatus.active,
            taskStatus: 'active',
            totalBytes: 100,
            completedBytes: 25,
          ),
        ],
      );
      await firstCall.future;
      final latest = service.synchronize(
        enabled: true,
        tasks: <DownloadTask>[
          _task(
            id: 'one',
            status: DownloadStatus.active,
            taskStatus: 'active',
            totalBytes: 100,
            completedBytes: 75,
          ),
        ],
      );
      releaseFirstCall.complete();
      await Future.wait(<Future<void>>[first, latest]);

      expect(applied, <double>[0.25, 0.75]);
    },
  );

  test('continues updating after an unchanged synchronization', () async {
    final applied = <double>[];
    final service = DesktopProgressService(
      isSupported: true,
      setProgress: (progress) async => applied.add(progress),
    );

    final firstTasks = <DownloadTask>[
      _task(
        id: 'one',
        status: DownloadStatus.active,
        taskStatus: 'active',
        totalBytes: 100,
        completedBytes: 25,
      ),
    ];
    await service.synchronize(enabled: true, tasks: firstTasks);
    await service.synchronize(enabled: true, tasks: firstTasks);
    await service.synchronize(
      enabled: true,
      tasks: <DownloadTask>[
        _task(
          id: 'one',
          status: DownloadStatus.active,
          taskStatus: 'active',
          totalBytes: 100,
          completedBytes: 75,
        ),
      ],
    );

    expect(applied, <double>[0.25, 0.75]);
  });

  test('does not call unsupported desktop integrations', () async {
    var called = false;
    final service = DesktopProgressService(
      isSupported: false,
      setProgress: (progress) async => called = true,
    );

    await service.clear();

    expect(called, isFalse);
  });
}
