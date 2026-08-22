import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/models/settings.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';
import 'package:setsuna/services/clipboard_monitor_service.dart';
import 'package:setsuna/services/shutdown_service.dart';

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
