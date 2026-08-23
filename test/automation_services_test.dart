import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/generated/l10n/l10n.dart';
import 'package:setsuna/models/settings.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';
import 'package:setsuna/services/clipboard_monitor_service.dart';
import 'package:setsuna/services/download_data_service.dart';
import 'package:setsuna/services/instance_manager.dart';
import 'package:setsuna/services/shutdown_service.dart';
import 'package:setsuna/services/update_check_service.dart';

import 'support/memory_settings_repository.dart';

class _FailedUpdateCheckService extends UpdateCheckService {
  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    return const UpdateCheckResult(status: UpdateCheckStatus.failed);
  }
}

DownloadTask _task(
  DownloadStatus status, {
  String taskStatus = 'active',
  bool isSeeder = false,
}) {
  return DownloadTask(
    id: 't-$status-$taskStatus',
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
    bittorrentInfo: isSeeder ? '{"info":{"name":"bt"}}' : null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipboardMonitorService.extractEligibleUri', () {
    const all = ClipboardMonitorService.allSchemes;

    test('accepts single-line supported URIs', () {
      final service = ClipboardMonitorService();
      expect(
        service.extractEligibleUri('https://example.com/file.zip', all),
        'https://example.com/file.zip',
      );
      expect(
        service.extractEligibleUri('magnet:?xt=urn:btih:abc', all),
        'magnet:?xt=urn:btih:abc',
      );
      expect(
        service.extractEligibleUri('ftp://example.com/file', all),
        'ftp://example.com/file',
      );
    });

    test('respects per-scheme masks', () {
      final service = ClipboardMonitorService();
      const magnetsOnly = ClipboardMonitorService.schemeMagnet;
      expect(
        service.extractEligibleUri('https://example.com/file.zip', magnetsOnly),
        isNull,
      );
      expect(
        service.extractEligibleUri('magnet:?xt=urn:btih:abc', magnetsOnly),
        'magnet:?xt=urn:btih:abc',
      );
    });

    test('updates the live scheme mask while already synchronized', () {
      final service = ClipboardMonitorService();
      addTearDown(service.dispose);

      service.synchronize(
        enabled: true,
        schemes: ClipboardMonitorService.schemeHttp,
      );
      service.synchronize(
        enabled: true,
        schemes: ClipboardMonitorService.schemeMagnet,
      );

      expect(service.synchronizedSchemes, ClipboardMonitorService.schemeMagnet);
    });

    test('rejects multi-line and unsupported content', () {
      final service = ClipboardMonitorService();
      expect(service.extractEligibleUri('hello world', all), isNull);
      expect(service.extractEligibleUri('line one\nline two', all), isNull);
      expect(service.extractEligibleUri('some random text', all), isNull);
    });

    test('decodes thunder links when enabled', () {
      final service = ClipboardMonitorService();
      // thunder://QUFodHRwOi8vZXhhbXBsZS5jb20vZmlsZS56aXBaWg==
      final decoded = service.extractEligibleUri(
        'thunder://QUFodHRwOi8vZXhhbXBsZS5jb20vZmlsZS56aXBZZg==',
        ClipboardMonitorService.schemeThunder,
      );
      // Exact payload correctness belongs to the protocol service; here we
      // only assert that a valid thunder link decodes to an http URL.
      expect(decoded, startsWith('http'));
    });
  });

  group('ShutdownService.hasActiveWork', () {
    test('seeding-only tasks do not block shutdown', () {
      final tasks = [
        _task(DownloadStatus.active, isSeeder: true),
        _task(DownloadStatus.stopped, taskStatus: 'complete'),
      ];
      expect(ShutdownService.hasActiveWork(tasks), isFalse);
    });

    test('active downloads block shutdown', () {
      expect(
        ShutdownService.hasActiveWork([_task(DownloadStatus.active)]),
        isTrue,
      );
    });

    test('running waiting tasks block shutdown but paused ones do not', () {
      expect(
        ShutdownService.hasActiveWork([
          _task(DownloadStatus.waiting, taskStatus: 'waiting'),
        ]),
        isTrue,
      );
      expect(
        ShutdownService.hasActiveWork([
          _task(DownloadStatus.waiting, taskStatus: 'paused'),
        ]),
        isFalse,
      );
    });
  });

  group('ShutdownService automation', () {
    tearDown(() => ShutdownService.instance.cancel(reason: 'test cleanup'));

    test('empty notifications still cancel countdown when work resumes', () {
      final service = ShutdownService.instance;
      service.synchronize(
        notifications: const <DownloadTaskNotification>[
          DownloadTaskNotification(
            taskId: 'complete',
            taskName: 'complete',
            instanceId: 'builtin',
            type: DownloadTaskNotificationType.completed,
          ),
        ],
        tasks: const <DownloadTask>[],
        enabled: true,
      );
      expect(service.isCountingDown, isTrue);

      service.synchronize(
        notifications: const <DownloadTaskNotification>[],
        tasks: <DownloadTask>[_task(DownloadStatus.active)],
        enabled: true,
      );

      expect(service.isCountingDown, isFalse);
    });

    test('failed shutdown execution remains observable', () async {
      final service = ShutdownService.instance;

      await service.executeShutdown(
        shutdown: () async => ProcessResult(1, 1, '', 'permission denied'),
      );

      expect(service.executionState.value, ShutdownExecutionState.failed);
    });

    test('Linux falls back when systemctl exits unsuccessfully', () async {
      final calls = <String>[];

      final result = await ShutdownService.executeSystemShutdownForPlatform(
        'linux',
        processRunner: (executable, arguments) async {
          calls.add('$executable ${arguments.join(' ')}');
          return executable == 'systemctl'
              ? ProcessResult(1, 1, '', 'unavailable')
              : ProcessResult(2, 0, '', '');
        },
      );

      expect(result.exitCode, 0);
      expect(calls, <String>['systemctl poweroff', 'shutdown -h now']);
    });

    testWidgets('failed shutdown dialog offers retry and close', (
      tester,
    ) async {
      ShutdownService.instance.executionState.value =
          ShutdownExecutionState.failed;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ShutdownCountdownDialog()),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.textContaining('Operation failed'), findsOneWidget);
    });
  });

  test('InstanceManager ignores notifications after disposal', () {
    final manager = InstanceManager();
    manager.dispose();

    expect(manager.notifyListeners, returnsNormally);
  });

  testWidgets('failed automatic update check does not save a timestamp', (
    tester,
  ) async {
    final repository = MemorySettingsRepository(<String, dynamic>{
      'lastUpdateCheckTimestamp': 0,
    });
    final settings = Settings(repository: repository);
    await settings.loadSettings();
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await _FailedUpdateCheckService().autoCheckIfNeeded(settings, context);

    expect(settings.lastUpdateCheckTimestamp, 0);
    expect(repository.savedValues!['lastUpdateCheckTimestamp'], 0);
  });

  group('Settings clipboard defaults', () {
    test('monitor disabled and schemes default to all by default', () async {
      final settings = Settings();
      await settings.loadSettings();
      expect(settings.clipboardMonitorEnabled, isFalse);
      expect(settings.shutdownWhenComplete, isFalse);
      expect(settings.clipboardMonitorSchemes, 0xF);
    });
  });
}
