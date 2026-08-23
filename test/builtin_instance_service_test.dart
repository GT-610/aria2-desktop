import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/models/settings.dart';
import 'package:setsuna/services/builtin_instance_service.dart';

import 'support/memory_settings_repository.dart';

Future<void> _closeSockets(Iterable<ServerSocket> sockets) async {
  for (final socket in sockets) {
    await socket.close();
  }
}

Future<List<ServerSocket>> _reserveConsecutiveLoopbackPorts(int count) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final sockets = <ServerSocket>[
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    ];
    final firstPort = sockets.first.port;
    if (firstPort > 65535 - count) {
      await _closeSockets(sockets);
      continue;
    }

    try {
      for (var offset = 1; offset < count; offset++) {
        sockets.add(
          await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            firstPort + offset,
          ),
        );
      }
      return sockets;
    } on SocketException {
      await _closeSockets(sockets);
    }
  }
  throw StateError('Could not reserve $count consecutive loopback ports');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BuiltinInstanceService helper methods', () {
    late BuiltinInstanceService service;

    setUp(() {
      service = BuiltinInstanceService();
      service.clearBoundSettings();
    });

    tearDown(() {
      service.clearBoundSettings();
    });

    test('unwraps repository settings snapshots', () {
      final snapshot = service.decodePersistedSettingsSnapshot(
        '{"schemaVersion":2,"settings":{"rpcListenPort":"16881"}}',
      );

      expect(snapshot, {'rpcListenPort': '16881'});
    });

    test('uses the bound loaded settings for the built-in instance', () async {
      final settings = Settings(
        repository: MemorySettingsRepository(<String, dynamic>{
          'rpcListenPort': 16882,
          'rpcSecret': 'secure-secret',
          'downloadDir': 'C:\\Downloads\\Setsuna',
        }),
      );
      await settings.loadSettings();

      service.bindSettings(settings);

      final instance = service.getBuiltinInstanceConfig();
      expect(instance.port, 16882);
      expect(instance.secret, 'secure-secret');
      expect(instance.downloadDir, 'C:\\Downloads\\Setsuna');
    });

    test(
      'active recovered RPC port overrides stale persisted settings',
      () async {
        final settings = Settings(
          repository: MemorySettingsRepository(<String, dynamic>{
            'rpcListenPort': 16882,
          }),
        );
        await settings.loadSettings();
        service.bindSettings(settings);

        service.setActiveRpcPortForTesting(16883);

        expect(service.getBuiltinInstanceConfig().port, 16883);

        service.setActiveRpcPortForTesting(null);
        expect(service.getBuiltinInstanceConfig().port, 16882);
      },
    );

    group('resolveEffectiveDhtListenPort', () {
      test('returns valid int port', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': 5000}),
          5000,
        );
      });

      test('returns default for null', () {
        expect(service.resolveEffectiveDhtListenPort({}), 26701);
      });

      test('returns default for zero', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': 0}),
          26701,
        );
      });

      test('returns default for negative', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': -1}),
          26701,
        );
      });

      test('returns default for over 65535', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': 70000}),
          26701,
        );
      });

      test('accepts boundary value 1', () {
        expect(service.resolveEffectiveDhtListenPort({'dhtListenPort': 1}), 1);
      });

      test('accepts boundary value 65535', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': 65535}),
          65535,
        );
      });

      test('parses valid string port', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': '8080'}),
          8080,
        );
      });

      test('parses string port with whitespace', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': '  5000  '}),
          5000,
        );
      });

      test('returns default for invalid string', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': 'abc'}),
          26701,
        );
      });

      test('returns default for out-of-range string', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': '99999'}),
          26701,
        );
      });

      test('returns default for non-int, non-string type', () {
        expect(
          service.resolveEffectiveDhtListenPort({'dhtListenPort': 3.14}),
          26701,
        );
      });
    });

    group('resolveEffectiveBtListenPort', () {
      test('returns configured port when non-empty', () {
        expect(
          service.resolveEffectiveBtListenPort({'btListenPort': '51413'}),
          '51413',
        );
      });

      test('returns configured port range', () {
        expect(
          service.resolveEffectiveBtListenPort({'btListenPort': '6881-6999'}),
          '6881-6999',
        );
      });

      test('returns default for empty string', () {
        expect(
          service.resolveEffectiveBtListenPort({'btListenPort': ''}),
          '6881-6999',
        );
      });

      test('returns default for whitespace-only string', () {
        expect(
          service.resolveEffectiveBtListenPort({'btListenPort': '   '}),
          '6881-6999',
        );
      });

      test('returns default for null', () {
        expect(service.resolveEffectiveBtListenPort({}), '6881-6999');
      });

      test('trims whitespace from configured port', () {
        expect(
          service.resolveEffectiveBtListenPort({'btListenPort': '  51413  '}),
          '51413',
        );
      });
    });

    group('resolveConfiguredFilePath', () {
      test('returns configured path when non-empty', () {
        expect(
          service.resolveConfiguredFilePath('/custom/path', '/default/path'),
          '/custom/path',
        );
      });

      test('returns fallback for empty string', () {
        expect(
          service.resolveConfiguredFilePath('', '/default/path'),
          '/default/path',
        );
      });

      test('returns fallback for null', () {
        expect(
          service.resolveConfiguredFilePath(null, '/default/path'),
          '/default/path',
        );
      });

      test('returns fallback for whitespace-only string', () {
        expect(
          service.resolveConfiguredFilePath('   ', '/default/path'),
          '/default/path',
        );
      });

      test('trims whitespace from configured path', () {
        expect(
          service.resolveConfiguredFilePath(
            '  /custom/path  ',
            '/default/path',
          ),
          '/custom/path',
        );
      });
    });

    group('formatSpeedLimitArg', () {
      test('returns 0 for zero', () {
        expect(service.formatSpeedLimitArg(0), '0');
      });

      test('returns 0 for negative', () {
        expect(service.formatSpeedLimitArg(-100), '0');
      });

      test('formats positive int with K suffix', () {
        expect(service.formatSpeedLimitArg(1024), '1024K');
      });

      test('formats positive double with K suffix', () {
        expect(service.formatSpeedLimitArg(1024.5), '1024K');
      });

      test('parses string value', () {
        expect(service.formatSpeedLimitArg('512'), '512K');
      });

      test('returns 0 for invalid string', () {
        expect(service.formatSpeedLimitArg('abc'), '0');
      });

      test('returns 0 for null', () {
        expect(service.formatSpeedLimitArg(null), '0');
      });

      test('returns 0 for empty string', () {
        expect(service.formatSpeedLimitArg(''), '0');
      });
    });

    group('effectiveSeedTime', () {
      test('returns 525600 when keepSeeding is true', () {
        expect(service.effectiveSeedTime(true, 60), 525600);
      });

      test('returns 525600 when keepSeeding true regardless of value', () {
        expect(service.effectiveSeedTime(true, 0), 525600);
        expect(service.effectiveSeedTime(true, null), 525600);
      });

      test('returns configured int value when not keeping', () {
        expect(service.effectiveSeedTime(false, 120), 120);
      });

      test('returns default 60 for null when not keeping', () {
        expect(service.effectiveSeedTime(false, null), 60);
      });

      test('parses string value', () {
        expect(service.effectiveSeedTime(false, '240'), 240);
      });

      test('returns default for invalid string', () {
        expect(service.effectiveSeedTime(false, 'abc'), 60);
      });

      test('converts double to int', () {
        expect(service.effectiveSeedTime(false, 90.5), 90);
      });
    });

    group('effectiveSeedRatio', () {
      test('returns 0.0 when keepSeeding is true', () {
        expect(service.effectiveSeedRatio(true, 1.0), 0.0);
      });

      test('returns 0.0 when keepSeeding true regardless of value', () {
        expect(service.effectiveSeedRatio(true, 2.0), 0.0);
        expect(service.effectiveSeedRatio(true, null), 0.0);
      });

      test('returns configured double value when not keeping', () {
        expect(service.effectiveSeedRatio(false, 2.5), 2.5);
      });

      test('returns default 1.0 for null when not keeping', () {
        expect(service.effectiveSeedRatio(false, null), 1.0);
      });

      test('parses string value', () {
        expect(service.effectiveSeedRatio(false, '3.0'), 3.0);
      });

      test('returns default for invalid string', () {
        expect(service.effectiveSeedRatio(false, 'abc'), 1.0);
      });

      test('converts int to double', () {
        expect(service.effectiveSeedRatio(false, 2), 2.0);
      });
    });
  });

  group('engine hardening helpers', () {
    setUp(BuiltinInstanceService.clearDetachShareOnlySupportCache);

    tearDown(() {
      BuiltinInstanceService.clearDetachShareOnlySupportCache();
      BuiltinInstanceService().clearBoundSettings();
    });

    test('sanitizeAllProxyArg rejects SOCKS schemes in any case', () {
      expect(BuiltinInstanceService.sanitizeAllProxyArg('socks5://h:1'), null);
      expect(BuiltinInstanceService.sanitizeAllProxyArg('SOCKS5://h:1'), null);
      expect(BuiltinInstanceService.sanitizeAllProxyArg('socks4a://h:1'), null);
      expect(BuiltinInstanceService.sanitizeAllProxyArg('socks5h://h:1'), null);
    });

    test('sanitizeAllProxyArg keeps HTTP and scheme-less proxies', () {
      expect(
        BuiltinInstanceService.sanitizeAllProxyArg('http://127.0.0.1:7890'),
        'http://127.0.0.1:7890',
      );
      expect(
        BuiltinInstanceService.sanitizeAllProxyArg('127.0.0.1:7890'),
        '127.0.0.1:7890',
      );
      expect(BuiltinInstanceService.sanitizeAllProxyArg('   '), null);
    });

    test('sanitizedEngineEnvironment strips proxy variables', () {
      final env = BuiltinInstanceService.sanitizedEngineEnvironment({
        'PATH': 'C:\\Windows',
        'HTTP_PROXY': 'http://proxy:8080',
        'https_proxy': 'http://proxy:8080',
        'ALL_PROXY': 'socks5://proxy:1080',
        'no_proxy': 'localhost',
      });

      expect(env['PATH'], 'C:\\Windows');
      // Blocked variables are removed from the inherited environment and
      // re-added as explicit empty overrides (lowercase canonical form).
      expect(env['http_proxy'], '');
      expect(env['https_proxy'], '');
      expect(env['all_proxy'], '');
      expect(env['no_proxy'], '');
      for (final name in ['HTTP_PROXY', 'ALL_PROXY']) {
        expect(env.containsKey(name), isFalse, reason: '$name should be gone');
      }
    });

    test('failed detach-share probe is retried instead of cached', () async {
      final service = BuiltinInstanceService();
      var calls = 0;

      Future<ProcessResult> runProbe(String _, List<String> _) async {
        calls++;
        if (calls == 1) {
          throw ProcessException('aria2c', const ['--version']);
        }
        return ProcessResult(1, 0, 'aria2 2.0.0', '');
      }

      expect(
        await service.engineSupportsDetachShareOnlyForTesting(runProbe),
        isFalse,
      );
      expect(
        await service.engineSupportsDetachShareOnlyForTesting(runProbe),
        isTrue,
      );
      expect(calls, 2);
    });

    test('successful unsupported detach-share probe caches false', () async {
      final service = BuiltinInstanceService();
      var calls = 0;

      Future<ProcessResult> runProbe(String _, List<String> _) async {
        calls++;
        return ProcessResult(1, 0, 'aria2 1.37.0', '');
      }

      expect(
        await service.engineSupportsDetachShareOnlyForTesting(runProbe),
        isFalse,
      );
      expect(
        await service.engineSupportsDetachShareOnlyForTesting(runProbe),
        isFalse,
      );
      expect(calls, 1);
    });

    test('recovery arguments isolate port, session, and log paths', () async {
      final directory = await Directory.systemTemp.createTemp(
        'setsuna-recovery-args-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final separator = Platform.pathSeparator;
      final sessionPath = '${directory.path}${separator}aria2.session';
      final logPath = '${directory.path}${separator}aria2.log';
      final downloadDir = '${directory.path}${separator}downloads';
      final settings = Settings(
        repository: MemorySettingsRepository(<String, dynamic>{
          'rpcListenPort': 16800,
          'sessionPath': sessionPath,
          'logPath': logPath,
          'downloadDir': downloadDir,
        }),
      );
      await settings.loadSettings();
      await File(sessionPath).create();

      final service = BuiltinInstanceService()..bindSettings(settings);
      final normalArgs = service.buildArgsForTesting(detachShareOnly: false);
      expect(normalArgs, contains('--rpc-listen-port=16800'));
      expect(normalArgs, contains('--save-session=$sessionPath'));
      expect(normalArgs, contains('--input-file=$sessionPath'));
      expect(normalArgs, contains('--log=$logPath'));

      var recoveryArgs = service.buildArgsForTesting(
        detachShareOnly: false,
        rpcPortOverride: 16801,
        useRecoveryPaths: true,
      );
      expect(recoveryArgs, contains('--rpc-listen-port=16801'));
      expect(service.getBuiltinInstanceConfig().port, 16800);
      final recoverySessionArg = recoveryArgs.firstWhere(
        (argument) => argument.startsWith('--save-session='),
      );
      final recoveryLogArg = recoveryArgs.firstWhere(
        (argument) => argument.startsWith('--log='),
      );
      final recoverySessionPath = recoverySessionArg.substring(
        '--save-session='.length,
      );
      expect(recoverySessionPath, isNot(sessionPath));
      expect(recoverySessionPath, contains('recovery-16801'));
      expect(recoveryLogArg, isNot('--log=$logPath'));
      expect(recoveryLogArg, contains('recovery-16801'));
      expect(recoveryArgs, isNot(contains('--input-file=$sessionPath')));

      await File(recoverySessionPath).create();
      recoveryArgs = service.buildArgsForTesting(
        detachShareOnly: false,
        rpcPortOverride: 16801,
        useRecoveryPaths: true,
      );
      expect(recoveryArgs, contains('--input-file=$recoverySessionPath'));
    });

    test('resolveAvailableRpcPort skips occupied loopback ports', () async {
      final reserved = await _reserveConsecutiveLoopbackPorts(4);
      addTearDown(() => _closeSockets(reserved));
      final preferredPort = reserved.first.port;
      final expectedSocket = reserved.removeLast();
      final expectedPort = expectedSocket.port;
      await expectedSocket.close();

      final service = BuiltinInstanceService();
      final resolved = await service.resolveAvailableRpcPort(
        preferredPort,
        maxAttempts: 3,
      );

      expect(resolved, expectedPort);
    });

    test('resolveAvailableRpcPort keeps a free preferred port', () async {
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final freePort = probe.port;
      await probe.close();

      final service = BuiltinInstanceService();
      final resolved = await service.resolveAvailableRpcPort(freePort);

      expect(resolved, freePort);
    });
  });
}
