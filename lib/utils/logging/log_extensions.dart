import 'package:logger/logger.dart';
import 'log_manager.dart';

/// Log extension class that provides more convenient logging methods
class AppLogger {
  final String _tag;
  final Logger _logger;
  
  /// Create a tagged logger instance
  AppLogger(this._tag) : _logger = LogManager().logger;
  
  /// Trace log
  void t(dynamic message) {
    _logger.t('[$_tag] $message');
  }
  
  /// Debug log
  void d(dynamic message) {
    _logger.d('[$_tag] $message');
  }
  
  /// Info log
  void i(dynamic message) {
    _logger.i('[$_tag] $message');
  }
  
  /// Warning log
  void w(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.w('[$_tag] $message', error: error, stackTrace: stackTrace);
  }
  
  /// Error log
  void e(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e('[$_tag] $message', error: error, stackTrace: stackTrace);
  }
  
  /// Fatal error log
  void f(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.f('[$_tag] $message', error: error, stackTrace: stackTrace);
  }
}

/// Log mixin for easy integration into pages or components
mixin Loggable {
  late final AppLogger logger;
  
  /// Initialize logger
  void initLogger() {
    logger = AppLogger(runtimeType.toString());
  }
}