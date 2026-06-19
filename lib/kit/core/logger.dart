import 'dart:io';

// ignore_for_file: avoid_print
abstract final class Loggers {
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
