import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/services/process_lifecycle_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('setsuna/process_lifecycle_test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'returns non-Windows lifecycle fallbacks without platform calls',
    () async {
      var called = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        called = true;
        return null;
      });
      final service = ProcessLifecycleService(
        channel: channel,
        isWindows: false,
      );

      expect(await service.canManageBuiltinProcess(), isTrue);
      expect(await service.attachToAppLifecycle(42), isTrue);
      expect(await service.isExpectedProcess(42, '/aria2c'), isFalse);
      expect(
        await service.findExpectedProcess(
          port: 6800,
          executablePath: '/aria2c',
        ),
        isNull,
      );
      expect(called, isFalse);
    },
  );

  test(
    'forwards Windows process lifecycle calls with typed arguments',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'ownsEngineLock' => true,
          'attachProcess' => true,
          'isExpectedProcess' => true,
          'findExpectedProcess' => 321,
          _ => null,
        };
      });
      final service = ProcessLifecycleService(
        channel: channel,
        isWindows: true,
      );

      expect(await service.canManageBuiltinProcess(), isTrue);
      expect(await service.attachToAppLifecycle(123), isTrue);
      expect(await service.isExpectedProcess(123, r'C:\aria2c.exe'), isTrue);
      expect(
        await service.findExpectedProcess(
          port: 16800,
          executablePath: r'C:\aria2c.exe',
        ),
        321,
      );

      expect(calls.map((call) => call.method), <String>[
        'ownsEngineLock',
        'attachProcess',
        'isExpectedProcess',
        'findExpectedProcess',
      ]);
      expect(calls[1].arguments, <String, Object>{'pid': 123});
      expect(calls[2].arguments, <String, Object>{
        'pid': 123,
        'executablePath': r'C:\aria2c.exe',
      });
      expect(calls[3].arguments, <String, Object>{
        'port': 16800,
        'executablePath': r'C:\aria2c.exe',
      });
    },
  );

  test(
    'allows startup when the ownership-lock plugin is unavailable',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException();
      });
      final service = ProcessLifecycleService(
        channel: channel,
        isWindows: true,
      );

      expect(await service.canManageBuiltinProcess(), isTrue);
    },
  );

  test('rejects startup when the ownership-lock query fails', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    final service = ProcessLifecycleService(channel: channel, isWindows: true);

    expect(await service.canManageBuiltinProcess(), isFalse);
  });
}
