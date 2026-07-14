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

  static void addLog(LogRecord record, {String? message, String? error}) {
    final color = _level2Color[record.level.name] ?? Colors.blue;
    final title = '[${DateTime.now().hourMinute}][${record.loggerName}]';
    final level = '[${record.level}]';
    final displayMessage = error == null
        ? '\n${message ?? record.message}'
        : '\n${message ?? record.message}: $error';
    lines.add('$title$level$displayMessage');

    var widgetCount = 1;
    final newWidgets = <Widget>[
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
              text: displayMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    ];
    if (record.stackTrace != null) {
      widgetCount++;
      newWidgets.add(
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
    newWidgets.add(UIs.height13);
    _widgetCounts.add(widgetCount);

    while (lines.length > maxLines) {
      final removeCount = _widgetCounts.removeAt(0);
      lines.removeAt(0);
      if (widgets.value.length >= removeCount) {
        widgets.value = widgets.value.sublist(removeCount);
      }
    }

    widgets.value = [...widgets.value, ...newWidgets];
  }

  static void clear() {
    widgets.value = [];
    lines.clear();
    _widgetCounts.clear();
  }

  static void copy() =>
      Clipboard.setData(ClipboardData(text: lines.join('\n')));
}
