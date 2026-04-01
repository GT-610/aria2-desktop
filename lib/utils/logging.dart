import 'package:fl_lib/fl_lib.dart';

enum Level { debug, info, warning, error }

void _log(
  Level level,
  String message, {
  dynamic error,
  StackTrace? stackTrace,
  String? tag,
}) {
  final prefix = tag != null ? '[$tag] ' : '';
  final msg = error != null
      ? '$prefix$message\nError: $error'
      : '$prefix$message';

  switch (level) {
    case Level.debug:
      dprint(msg);
    case Level.info:
      dprint(msg);
    case Level.warning:
      dprint(msg);
    case Level.error:
      lprint(msg);
      if (stackTrace != null) {
        lprint(stackTrace.toString());
      }
  }
}

mixin Loggable {
  void log(
    Level level,
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    _log(
      level,
      message,
      error: error,
      stackTrace: stackTrace,
      tag: runtimeType.toString(),
    );
  }

  void d(String message) => log(Level.debug, message);
  void i(String message) => log(Level.info, message);
  void w(String message, {dynamic error, StackTrace? stackTrace}) =>
      log(Level.warning, message, error: error, stackTrace: stackTrace);
  void e(String message, {dynamic error, StackTrace? stackTrace}) =>
      log(Level.error, message, error: error, stackTrace: stackTrace);
}
