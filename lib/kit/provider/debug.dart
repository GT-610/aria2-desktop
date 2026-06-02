import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../core/ext/datetime.dart';
import '../core/ext/obj.dart';
import '../res/ui.dart';

const _level2Color = {
  'INFO': Colors.cyan,
  'WARNING': Colors.yellow,
  'SEVERE': Color(0xffbb2d6f),
};

final class DebugProvider {
  static const int maxLines = 100;
  static final widgets = <Widget>[].vn;
  static final lines = <String>[];
  static final _widgetCounts = <int>[];

  static void addLog(LogRecord record) {
    final color = _level2Color[record.level.name] ?? Colors.blue;
    final title = '[${DateTime.now().hourMinute}][${record.loggerName}]';
    final level = '[${record.level}]';
    final message = record.error == null
        ? '\n${record.message}'
        : '\n${record.message}: ${record.error}';
    lines.add('$title$level$message');

    var widgetCount = 1;
    widgets.value.add(
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: title,
              style: TextStyle(color: color),
            ),
            TextSpan(
              text: level,
              style: TextStyle(color: color),
            ),
            TextSpan(
              text: message,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    if (record.stackTrace != null) {
      widgetCount++;
      widgets.value.add(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            '${record.stackTrace}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    widgetCount++;
    widgets.value.add(UIs.height13);
    _widgetCounts.add(widgetCount);

    while (lines.length > maxLines) {
      final removed = _widgetCounts.removeAt(0);
      lines.removeAt(0);
      if (widgets.value.length >= removed) {
        widgets.value.removeRange(0, removed);
      }
    }
    widgets.notify();
  }

  static void clear() {
    widgets.value.clear();
    lines.clear();
    _widgetCounts.clear();
    widgets.notify();
  }

  static void copy() =>
      Clipboard.setData(ClipboardData(text: lines.join('\n')));
}
