extension DateTimeX on DateTime {
  String get hourMinute {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static int get timestamp => DateTime.now().millisecondsSinceEpoch;
}
