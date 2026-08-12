import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:setsuna/services/debug_log_store.dart';
import 'package:setsuna/utils/logging.dart';

void main() {
  setUp(DebugLogStore.clear);
  tearDown(DebugLogStore.clear);

  test('keeps only the newest log entries', () {
    for (var index = 0; index < DebugLogStore.maximumEntries + 5; index++) {
      DebugLogStore.add(
        LogRecord(Level.INFO, 'message-$index', 'Test'),
        message: 'message-$index',
        stackTrace: null,
      );
    }

    expect(
      DebugLogStore.entries.value,
      hasLength(DebugLogStore.maximumEntries),
    );
    expect(DebugLogStore.entries.value.first.message, 'message-5');
    expect(
      DebugLogStore.entries.value.last.message,
      'message-${DebugLogStore.maximumEntries + 4}',
    );
  });

  test('formats logger, level, message, and stack trace', () {
    final entry = DebugLogEntry(
      timestamp: DateTime(2026, 8, 12, 9, 5),
      loggerName: 'Rpc',
      level: Level.WARNING,
      message: 'Connection delayed',
      stackTrace: 'trace line',
    );

    expect(
      entry.plainText,
      '[09:05][Rpc][WARNING] Connection delayed\ntrace line',
    );
  });

  test('stores redacted stack traces from the root logger', () async {
    initializeAppLogging(level: Level.ALL);

    taggedLogger('Test').e(
      'RPC failed',
      stackTrace: StackTrace.fromString('authorization: Bearer private-token'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      DebugLogStore.entries.value.single.stackTrace,
      'authorization: [REDACTED]',
    );
  });
}
