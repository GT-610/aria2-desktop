import 'package:logger/logger.dart';
import 'log_config.dart';

/// Log Manager - Singleton Pattern
class LogManager {
  /// Private constructor
  LogManager._privateConstructor();
  
  /// Singleton instance
  static final LogManager _instance = LogManager._privateConstructor();
  
  /// Get singleton instance
  factory LogManager() => _instance;
  
  /// Global Logger instance
  Logger? _logger;
  
  /// Get Logger instance
  Logger get logger {
    _logger ??= _initLogger();
    return _logger!;
  }
  
  /// Initialize Logger
  Logger _initLogger() {
    return Logger(
      level: LogConfig.logLevel,
      printer: PrettyPrinter(
        methodCount: LogConfig.methodCount,
        errorMethodCount: LogConfig.errorMethodCount,
        lineLength: LogConfig.lineLength,
        colors: LogConfig.useColors,
        printEmojis: LogConfig.printEmojis,
        dateTimeFormat: (DateTime time) => LogConfig.dateTimeFormat(time),
      ),
      filter: ProductionFilter(), // Use production environment filter
    );
  }
  
  /// Reset Logger instance
  void resetLogger() {
    _logger?.close();
    _logger = _initLogger();
  }
  
  /// Set log level
  void setLogLevel(Level level) {
    Logger.level = level;
  }
}