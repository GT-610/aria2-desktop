import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

class DebugLogEntry {
  const DebugLogEntry({
    required this.timestamp,
    required this.loggerName,
    required this.level,
    required this.message,
    this.stackTrace,
  });

  final DateTime timestamp;
  final String loggerName;
  final Level level;
  final String message;
  final StackTrace? stackTrace;

  String get plainText {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
    final base = '[$time][$loggerName][${level.name}] $message';
    return stackTrace == null ? base : '$base\n$stackTrace';
  }
}

class DebugLogStore {
  DebugLogStore._();

  static const int maximumEntries = 100;
  static final ValueNotifier<List<DebugLogEntry>> entries =
      ValueNotifier<List<DebugLogEntry>>(const []);

  static void add(LogRecord record, {required String message}) {
    final next = <DebugLogEntry>[
      ...entries.value,
      DebugLogEntry(
        timestamp: record.time,
        loggerName: record.loggerName,
        level: record.level,
        message: message,
        stackTrace: record.stackTrace,
      ),
    ];
    entries.value = next.length <= maximumEntries
        ? List<DebugLogEntry>.unmodifiable(next)
        : List<DebugLogEntry>.unmodifiable(
            next.sublist(next.length - maximumEntries),
          );
  }

  static void clear() {
    entries.value = const [];
  }

  static Future<void> copy() {
    return Clipboard.setData(
      ClipboardData(
        text: entries.value.map((entry) => entry.plainText).join('\n'),
      ),
    );
  }
}
