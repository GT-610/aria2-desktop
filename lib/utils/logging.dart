import 'dart:async';

import 'package:logging/logging.dart';

import '../services/debug_log_store.dart';

Level get defaultLogLevel => Level.INFO;

StreamSubscription<LogRecord>? _rootLogSubscription;

String _formatRecord(LogRecord record) {
  final message = _redactSensitiveText(
    '[${record.loggerName}][${record.level.name}] ${record.message}',
  );
  if (record.error == null) {
    return message;
  }
  return '$message\nError: ${_redactSensitiveText(record.error.toString())}';
}

String _redactSensitiveText(String value) {
  var redacted = value.replaceAll(
    RegExp(r'''token:[^\s,\]"']+''', caseSensitive: false),
    'token:[REDACTED]',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(
      r'(--(?:rpc-secret|rpc-user|rpc-passwd)=)([^\s]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[REDACTED]',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(r'(authorization\s*[:=]\s*)([^\r\n,}]+)', caseSensitive: false),
    (match) => '${match.group(1)}[REDACTED]',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(
      r'("(?:secret|rpcSecret|password)"\s*:\s*")([^"]*)(")',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}[REDACTED]${match.group(3)}',
  );
  return redacted;
}

void initializeAppLogging({Level? level}) {
  final nextLevel = level ?? defaultLogLevel;
  Logger.root.level = nextLevel;
  _rootLogSubscription?.cancel();
  _rootLogSubscription = Logger.root.onRecord.listen((record) {
    final displayMessage = record.error == null
        ? _redactSensitiveText(record.message)
        : '${_redactSensitiveText(record.message)}: '
              '${_redactSensitiveText(record.error.toString())}';
    DebugLogStore.add(record, message: displayMessage);
    // ignore: avoid_print
    print(_formatRecord(record));
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print(record.stackTrace!);
    }
  });
}

Logger taggedLogger(String tag) => Logger(tag);

extension LoggerLevelX on Logger {
  void i(String message, {Object? error, StackTrace? stackTrace}) =>
      log(Level.INFO, message, error, stackTrace);

  void w(String message, {Object? error, StackTrace? stackTrace}) =>
      log(Level.WARNING, message, error, stackTrace);

  void e(String message, {Object? error, StackTrace? stackTrace}) =>
      log(Level.SEVERE, message, error, stackTrace);
}

mixin Loggable {
  Logger get logger => taggedLogger(runtimeType.toString());

  void i(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.i(message, error: error, stackTrace: stackTrace);

  void w(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.w(message, error: error, stackTrace: stackTrace);

  void e(String message, {Object? error, StackTrace? stackTrace}) =>
      logger.e(message, error: error, stackTrace: stackTrace);
}
