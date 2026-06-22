import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/models/settings.dart';

void main() {
  group('Settings', () {
    group('default values', () {
      late Settings settings;

      setUp(() {
        settings = Settings();
      });

      test('has expected default autoStart', () {
        expect(settings.autoStart, isFalse);
      });

      test('has expected default runMode', () {
        expect(settings.runMode, AppRunMode.tray);
      });

      test('has expected default maxConcurrentDownloads', () {
        expect(settings.maxConcurrentDownloads, 5);
      });

      test('has expected default maxConnectionPerServer', () {
        expect(settings.maxConnectionPerServer, 16);
      });

      test('has expected default split', () {
        expect(settings.split, 16);
      });

      test('has expected default continueDownloads', () {
        expect(settings.continueDownloads, isTrue);
      });

      test('has expected default speed limits', () {
        expect(settings.maxOverallDownloadLimit, 0);
        expect(settings.maxOverallUploadLimit, 0);
      });

      test('has expected default BT settings', () {
        expect(settings.btSaveMetadata, isTrue);
        expect(settings.btForceEncryption, isFalse);
        expect(settings.keepSeeding, isFalse);
        expect(settings.seedRatio, 1.0);
        expect(settings.seedTime, 60);
        expect(settings.btListenPort, '6881-6999');
        expect(settings.btTracker, '');
        expect(settings.btExcludeTracker, '');
      });

      test('has expected default proxy settings', () {
        expect(settings.proxyEnabled, isFalse);
        expect(settings.allProxy, '');
        expect(settings.noProxy, '');
      });

      test('has expected default DHT settings', () {
        expect(settings.dhtListenPort, 26701);
        expect(settings.enableDht6, isTrue);
        expect(settings.enableUpnp, isTrue);
      });

      test('has expected default UI settings', () {
        expect(settings.autoHideWindow, isFalse);
        expect(settings.showTraySpeed, isTrue);
        expect(settings.taskNotification, isTrue);
        expect(settings.skipDeleteConfirm, isFalse);
        expect(settings.resumeAllOnLaunch, isFalse);
        expect(settings.showDownloadsAfterAdd, isTrue);
        expect(settings.showProgressBar, isTrue);
        expect(settings.hideTitleBar, isFalse);
      });

      test('has expected default file settings', () {
        expect(settings.autoFileRenaming, isTrue);
        expect(settings.allowOverwrite, isFalse);
      });

      test('has expected default tracker settings', () {
        expect(settings.autoSyncTracker, isTrue);
        expect(settings.lastSyncTrackerTime, 0);
        expect(
          settings.trackerSource,
          'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt',
        );
      });

      test('isLoaded is false before loadSettings', () {
        expect(settings.isLoaded, isFalse);
      });
    });

    group('AppRunMode', () {
      test('has three values', () {
        expect(AppRunMode.values.length, 3);
      });

      test('contains standard, tray, hideTray', () {
        expect(AppRunMode.values, contains(AppRunMode.standard));
        expect(AppRunMode.values, contains(AppRunMode.tray));
        expect(AppRunMode.values, contains(AppRunMode.hideTray));
      });
    });

    group('normalizeBtTracker', () {
      late Settings settings;

      setUp(() {
        settings = Settings();
      });

      test('returns empty string for empty input', () {
        expect(settings.normalizeBtTracker(''), '');
      });

      test('returns single tracker unchanged', () {
        const tracker = 'udp://tracker.example.com:6969/announce';
        expect(settings.normalizeBtTracker(tracker), tracker);
      });

      test('preserves comma-separated trackers', () {
        const input =
            'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce';
        expect(settings.normalizeBtTracker(input), input);
      });

      test('normalizes newline-separated trackers to comma-separated', () {
        const input =
            'udp://t1.example.com:6969/announce\nudp://t2.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('normalizes CRLF-separated trackers', () {
        const input =
            'udp://t1.example.com:6969/announce\r\nudp://t2.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('strips empty entries from consecutive delimiters', () {
        const input =
            'udp://t1.example.com:6969/announce\n\n\nudp://t2.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('trims whitespace from each tracker', () {
        const input =
            '  udp://t1.example.com:6969/announce  ,  udp://t2.example.com:6969/announce  ';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('filters out empty entries after trimming', () {
        const input =
            'udp://t1.example.com:6969/announce, , udp://t2.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('handles mixed comma and newline separators', () {
        const input =
            'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce\nudp://t3.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce,udp://t3.example.com:6969/announce',
        );
      });
    });
  });
}
