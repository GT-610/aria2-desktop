import 'package:logger/logger.dart';

/// Log system configuration class
class LogConfig {
  /// Log level configuration
  static const Level logLevel = Level.trace;
  
  /// Whether to display colors in the console
  static const bool useColors = true;
  
  /// Number of method calls to display
  static const int methodCount = 2;
  
  /// Number of method calls to display when an error occurs
  static const int errorMethodCount = 8;
  
  /// Log output line width
  static const int lineLength = 120;
  
  /// Whether to display emojis
  static const bool printEmojis = true;
  
  /// DateTime format function
  static String Function(DateTime) dateTimeFormat = (DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')} (+${diff.inMilliseconds}ms)';
  };
}