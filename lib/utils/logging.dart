import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:logging/logging.dart';

Level get defaultLogLevel => BuildMode.isDebug ? Level.ALL : Level.INFO;

StreamSubscription<LogRecord>? _rootLogSubscription;

String _formatRecord(LogRecord record) {
  final message =
      '[${record.loggerName}][${record.level.name}] ${record.message}';
  if (record.error == null) {
    return message;
  }
  return '$message\nError: ${record.error}';
}

void initializeAppLogging({Level? level}) {
  final nextLevel = level ?? defaultLogLevel;
  Logger.root.level = nextLevel;
  _rootLogSubscription?.cancel();
  _rootLogSubscription = Logger.root.onRecord.listen((record) {
    DebugProvider.addLog(record);
    Loggers.log(_formatRecord(record));
    if (record.stackTrace != null) {
      Loggers.log(record.stackTrace!);
    }
  });
}

Logger taggedLogger(String tag) => Logger(tag);

extension LoggerLevelX on Logger {
  void d(String message, {Object? error, StackTrace? stackTrace}) =>
      log(Level.FINE, message, error, stackTrace);

  void i(String message, {Object? error, StackTrace? stackTrace}) =>
      log(Level.INFO, message, error, stackTrace);

  void w(String message, {Object? error, StackTrace? stackTrace}) =>
      log(Level.WARNING, message, error, stackTrace);

  void e(String message, {Object? error, StackTrace? stackTrace}) =>
      log(Level.SEVERE, message, error, stackTrace);
}

mixin Loggable {
  Logger get logger => taggedLogger(runtimeType.toString());

  void d(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.d(message, error: error, stackTrace: stackTrace);

  void i(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.i(message, error: error, stackTrace: stackTrace);

  void w(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.w(message, error: error, stackTrace: stackTrace);

  void e(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.e(message, error: error, stackTrace: stackTrace);
}
