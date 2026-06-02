import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../core/ext/datetime.dart';
import '../core/ext/obj.dart';
import '../res/ui.dart';

const _level2Color = {
  'INFO': Colors.cyan,
  'WARNING': Colors.yellow,
  'ERROR': Color(0xffbb2d6f),
};

final class DebugProvider {
  static const int maxLines = 100;
  static final widgets = <Widget>[].vn;
  static final lines = <String>[];

  static void addLog(LogRecord record) {
    final color = _level2Color[record.level.name] ?? Colors.blue;
    final title = '[${DateTime.now().hourMinute}][${record.loggerName}]';
    final level = '[${record.level}]';
    final message = record.error == null
        ? '\n${record.message}'
        : '\n${record.message}: ${record.error}';
    lines.add('$title$level$message');
    widgets.value.add(Text.rich(TextSpan(
      children: [
        TextSpan(text: title, style: TextStyle(color: color)),
        TextSpan(text: level, style: TextStyle(color: color)),
        TextSpan(
          text: message,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    )));
    if (record.stackTrace != null) {
      widgets.value.add(SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          '${record.stackTrace}',
          style: const TextStyle(color: Colors.white),
        ),
      ));
    }
    widgets.value.add(UIs.height13);
    if (widgets.value.length > maxLines) {
      widgets.value.removeRange(0, widgets.value.length - maxLines);
    }
    widgets.notify();

    if (lines.length > maxLines) {
      lines.removeRange(0, lines.length - maxLines);
    }
  }

  static void clear() {
    widgets.value.clear();
    lines.clear();
    widgets.notify();
  }

  static void copy() => Clipboard.setData(ClipboardData(text: lines.join('\n')));
}
