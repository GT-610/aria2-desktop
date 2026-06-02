import 'dart:io';

import 'package:logging/logging.dart';

import 'build.dart';

abstract final class Loggers {
  static final root = Logger('Root');
  static final store = Logger('Store');
  static final route = Logger('Route');
  static final app = Logger('App');

  static final sourceReg = RegExp(r'\((.+):(\d+):(\d+)\)');

  static void log(Object message, {int skipFrames = 1}) {
    final traceLines = StackTrace.current.toString().split('\n');

    if (traceLines.length > skipFrames) {
      final caller = traceLines[skipFrames];
      final match = sourceReg.firstMatch(caller);
      if (match != null) {
        String? file = match.group(1)?.replaceFirst('file://', '');
        final line = match.group(2);
        if (file != null) {
          final pwd = Directory.current.path;
          if (file.startsWith(pwd)) {
            file = file.substring(pwd.length + 1);
            file = './$file';
          }
        }
        print('[$file:$line] $message');
        return;
      }
    }
    print(message);
  }
}

void dprint(Object? msg, [Object? msg2, Object? msg3, Object? msg4]) {
  if (!BuildMode.isDebug) return;
  lprint(msg, msg2, msg3, msg4, 3);
}

void lprint(
  Object? msg, [
  Object? msg2,
  Object? msg3,
  Object? msg4,
  int skipFrames = 2,
]) {
  final sb = StringBuffer();
  sb.write(msg.toString());

  if (msg2 != null) {
    sb.write('\n$msg2');
    if (msg3 != null) {
      sb.write('\n$msg3');
      if (msg4 != null) {
        sb.write('\n$msg4');
      }
    }
  }
  final str = sb.toString();
  Loggers.log(str, skipFrames: skipFrames);
}
