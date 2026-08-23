import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/models/settings.dart';
import 'package:setsuna/utils/speed_schedule.dart';

import 'support/memory_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        expect(settings.speedLimitEnabled, isTrue);
        expect(settings.speedScheduleEnabled, isFalse);
        expect(settings.speedScheduleDays, allDaysBitmask);
        expect(settings.speedScheduleStartMinutes, 0);
        expect(settings.speedScheduleEndMinutes, minutesPerDay);
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
        expect(settings.keepAwake, isFalse);
        expect(settings.shutdownWhenComplete, isFalse);
        expect(settings.fileCategoryRoutingEnabled, isFalse);
        expect(settings.fileCategoryRules, isEmpty);
        expect(settings.lastUpdateCheckTimestamp, 0);
        expect(settings.clipboardMonitorEnabled, isFalse);
        expect(settings.clipboardMonitorSchemes, 0xF);
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

    group('settings hydration', () {
      test('exposes typed settings for the built-in instance', () async {
        final repository = MemorySettingsRepository(<String, dynamic>{
          'rpcListenPort': 16888,
          'rpcSecret': 'secure-secret',
          'continueDownloads': false,
          'downloadDir': 'C:\\Downloads\\Setsuna',
          'maxOverallDownloadLimit': 1024,
          'btForceEncryption': true,
          'seedRatio': 2.5,
          'proxyEnabled': true,
          'allProxy': 'http://127.0.0.1:7890',
          'enableUpnp': false,
          'userAgent': 'Setsuna Test',
        });
        final settings = Settings(repository: repository);

        await settings.loadSettings();

        final snapshot = settings.toBuiltinInstanceSettings();
        expect(snapshot['rpcListenPort'], 16888);
        expect(snapshot['rpcSecret'], 'secure-secret');
        expect(snapshot['continueDownloads'], isFalse);
        expect(snapshot['downloadDir'], 'C:\\Downloads\\Setsuna');
        expect(snapshot['maxOverallDownloadLimit'], 1024);
        expect(snapshot['btForceEncryption'], isTrue);
        expect(snapshot['seedRatio'], 2.5);
        expect(snapshot['proxyEnabled'], isTrue);
        expect(snapshot['allProxy'], 'http://127.0.0.1:7890');
        expect(snapshot['enableUpnp'], isFalse);
        expect(snapshot['userAgent'], 'Setsuna Test');
      });

      test(
        'repairs individual legacy values without resetting valid fields',
        () async {
          final repository = MemorySettingsRepository(<String, dynamic>{
            'autoStart': 'true',
            'runMode': 'invalid',
            'taskNotification': false,
            'themeMode': 'dark',
            'primaryColor': 0xFF123456,
            'locale': 'zh_CN',
            'rpcListenPort': '16801',
            'maxConcurrentDownloads': 999,
            'maxConnectionPerServer': 32.0,
            'split': '8',
            'continueDownloads': 1,
            'downloadDir': 123,
            'maxOverallDownloadLimit': '-1',
            'maxOverallUploadLimit': '2048',
            'seedRatio': '2.5',
            'seedTime': 30.0,
            'btTracker': 'udp://one\n udp://two',
            'dhtListenPort': '70000',
            'trackerSource': '',
            'userAgent': '',
          });
          final settings = Settings(repository: repository);

          await settings.loadSettings();

          expect(settings.isLoaded, isTrue);
          expect(settings.autoStart, isTrue);
          expect(settings.runMode, AppRunMode.tray);
          expect(settings.taskNotification, isFalse);
          expect(settings.themeMode, ThemeMode.dark);
          expect(settings.primaryColor, const Color(0xFF123456));
          expect(settings.locale, const Locale('zh'));
          expect(settings.rpcListenPort, 16801);
          expect(settings.maxConcurrentDownloads, 5);
          expect(settings.maxConnectionPerServer, 32);
          expect(settings.split, 8);
          expect(settings.continueDownloads, isTrue);
          expect(settings.downloadDir, isNotEmpty);
          expect(settings.maxOverallDownloadLimit, 0);
          expect(settings.maxOverallUploadLimit, 2048);
          expect(settings.seedRatio, 2.5);
          expect(settings.seedTime, 30);
          expect(settings.btTracker, 'udp://one,udp://two');
          expect(settings.dhtListenPort, 26701);
          expect(repository.savedValues, isNotNull);
          expect(repository.savedValues!['autoStart'], isTrue);
          expect(repository.savedValues!['rpcListenPort'], 16801);
          expect(repository.savedValues!['maxConcurrentDownloads'], 5);
          expect(repository.savedValues!['locale'], 'zh');
        },
      );

      test('does not rewrite already normalized settings', () async {
        final repository = MemorySettingsRepository(<String, dynamic>{
          'autoStart': false,
          'minimizeToTray': true,
          'runMode': 'tray',
          'autoHideWindow': false,
          'showTraySpeed': true,
          'taskNotification': true,
          'protocolMagnetEnabled': false,
          'protocolThunderEnabled': false,
          'skipDeleteConfirm': false,
          'resumeAllOnLaunch': false,
          'showDownloadsAfterAdd': true,
          'showProgressBar': true,
          'keepAwake': false,
          'hideTitleBar': false,
          'themeMode': 'system',
          'primaryColor': '4280391411',
          'customColorCode': null,
          'locale': null,
          'rpcListenPort': 16800,
          'rpcSecret': '',
          'maxConcurrentDownloads': 5,
          'maxConnectionPerServer': 16,
          'split': 16,
          'continueDownloads': true,
          'downloadDir': 'C:\\Downloads',
          'maxOverallDownloadLimit': 0,
          'maxOverallUploadLimit': 0,
          'btSaveMetadata': true,
          'btForceEncryption': false,
          'btLoadSavedMetadata': true,
          'keepSeeding': false,
          'seedRatio': 1.0,
          'seedTime': 60,
          'btListenPort': '6881-6999',
          'btTracker': '',
          'btExcludeTracker': '',
          'proxyEnabled': false,
          'allProxy': '',
          'noProxy': '',
          'dhtListenPort': 26701,
          'enableDht6': true,
          'enableUpnp': true,
          'sessionPath': '',
          'logPath': '',
          'autoSyncTracker': true,
          'lastSyncTrackerTime': 0,
          'trackerSource':
              'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt',
          'autoFileRenaming': true,
          'allowOverwrite': false,
          'userAgent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/120.0.0.0 Safari/537.36',
        });

        await Settings(repository: repository).loadSettings();

        expect(repository.savedValues, isNull);
      });

      test('drops the obsolete minimize-to-tray field on save', () async {
        final repository = MemorySettingsRepository(<String, dynamic>{
          'minimizeToTray': false,
        });
        final settings = Settings(repository: repository);

        await settings.loadSettings();
        expect(settings.runMode, AppRunMode.standard);

        await settings.setRunMode(AppRunMode.tray);

        expect(repository.savedValues, isNot(contains('minimizeToTray')));
        expect(repository.savedValues!['runMode'], 'tray');
      });

      test('persists the keep-awake preference', () async {
        final repository = MemorySettingsRepository(<String, dynamic>{});
        final settings = Settings(repository: repository);

        await settings.loadSettings();
        await settings.setKeepAwake(true);

        expect(settings.keepAwake, isTrue);
        expect(repository.savedValues!['keepAwake'], isTrue);
      });

      test('persists speed switches and schedule values', () async {
        final repository = MemorySettingsRepository(<String, dynamic>{});
        final settings = Settings(repository: repository);

        await settings.loadSettings();
        await settings.setSpeedLimitEnabled(false);
        await settings.setSpeedSchedule(
          enabled: true,
          days: 0x01,
          startMinutes: 22 * 60,
          endMinutes: 6 * 60,
        );

        expect(repository.savedValues!['speedLimitEnabled'], isFalse);
        expect(repository.savedValues!['speedScheduleEnabled'], isTrue);
        expect(repository.savedValues!['speedScheduleDays'], 0x01);
        expect(repository.savedValues!['speedScheduleStartMinutes'], 22 * 60);
        expect(repository.savedValues!['speedScheduleEndMinutes'], 6 * 60);

        final reloaded = Settings(
          repository: MemorySettingsRepository(repository.savedValues!),
        );
        await reloaded.loadSettings();
        expect(reloaded.speedLimitEnabled, isFalse);
        expect(reloaded.speedScheduleEnabled, isTrue);
        expect(reloaded.speedScheduleDays, 0x01);
        expect(reloaded.speedScheduleStartMinutes, 22 * 60);
        expect(reloaded.speedScheduleEndMinutes, 6 * 60);
      });

      test('repairs schedule times that are not half-hour choices', () async {
        final repository = MemorySettingsRepository(<String, dynamic>{
          'speedScheduleStartMinutes': 615,
          'speedScheduleEndMinutes': 1450,
        });
        final settings = Settings(repository: repository);

        await settings.loadSettings();

        expect(settings.speedScheduleStartMinutes, 0);
        expect(settings.speedScheduleEndMinutes, minutesPerDay);
        expect(repository.savedValues!['speedScheduleStartMinutes'], 0);
        expect(
          repository.savedValues!['speedScheduleEndMinutes'],
          minutesPerDay,
        );

        expect(
          () => settings.setSpeedSchedule(startMinutes: -30),
          throwsArgumentError,
        );
        expect(
          () => settings.setSpeedSchedule(endMinutes: 601),
          throwsArgumentError,
        );
        expect(settings.speedScheduleStartMinutes, 0);
        expect(settings.speedScheduleEndMinutes, minutesPerDay);
      });

      test('reset restores all persisted automation preferences', () async {
        final repository = MemorySettingsRepository(<String, dynamic>{
          'shutdownWhenComplete': true,
          'fileCategoryRoutingEnabled': true,
          'fileCategoryRulesJson':
              '["{\\"extensions\\":[\\"zip\\"],'
              '\\"subdirectory\\":\\"Archives\\"}"]',
          'lastUpdateCheckTimestamp': 123,
          'clipboardMonitorEnabled': true,
          'clipboardMonitorSchemes': 0x04,
          'speedLimitEnabled': false,
          'speedScheduleEnabled': true,
          'speedScheduleDays': 0x01,
          'speedScheduleStartMinutes': 1320,
          'speedScheduleEndMinutes': 360,
        });
        final settings = Settings(repository: repository);
        await settings.loadSettings();

        await settings.resetToDefaults();

        expect(settings.shutdownWhenComplete, isFalse);
        expect(settings.fileCategoryRoutingEnabled, isFalse);
        expect(settings.fileCategoryRules, isEmpty);
        expect(settings.lastUpdateCheckTimestamp, 0);
        expect(settings.clipboardMonitorEnabled, isFalse);
        expect(settings.clipboardMonitorSchemes, 0xF);
        expect(settings.speedLimitEnabled, isTrue);
        expect(settings.speedScheduleEnabled, isFalse);
        expect(settings.speedScheduleDays, allDaysBitmask);
        expect(settings.speedScheduleStartMinutes, 0);
        expect(settings.speedScheduleEndMinutes, minutesPerDay);
        expect(repository.savedValues!['shutdownWhenComplete'], isFalse);
        expect(repository.savedValues!['speedLimitEnabled'], isTrue);
      });
    });
  });
}
