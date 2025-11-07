import 'package:logger/logger.dart';
import 'log_manager.dart';

/// 日志扩展类，提供更便捷的日志记录方法
class AppLogger {
  final String _tag;
  final Logger _logger;
  
  /// 创建带标签的日志实例
  AppLogger(this._tag) : _logger = LogManager().logger;
  
  /// 跟踪日志
  void t(dynamic message) {
    _logger.t('[$_tag] $message');
  }
  
  /// 调试日志
  void d(dynamic message) {
    _logger.d('[$_tag] $message');
  }
  
  /// 信息日志
  void i(dynamic message) {
    _logger.i('[$_tag] $message');
  }
  
  /// 警告日志
  void w(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.w('[$_tag] $message', error: error, stackTrace: stackTrace);
  }
  
  /// 错误日志
  void e(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e('[$_tag] $message', error: error, stackTrace: stackTrace);
  }
  
  /// 致命错误日志
  void f(dynamic message, {dynamic error, StackTrace? stackTrace}) {
    _logger.f('[$_tag] $message', error: error, stackTrace: stackTrace);
  }
}

/// 日志混入，方便页面或组件快速接入日志系统
mixin Loggable {
  late final AppLogger logger;
  
  /// 初始化日志器
  void initLogger() {
    logger = AppLogger(runtimeType.toString());
  }
}