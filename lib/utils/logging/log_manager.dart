import 'package:logger/logger.dart';
import 'log_config.dart';

/// 日志管理器 - 单例模式
class LogManager {
  /// 私有构造函数
  LogManager._privateConstructor();
  
  /// 单例实例
  static final LogManager _instance = LogManager._privateConstructor();
  
  /// 获取单例实例
  factory LogManager() => _instance;
  
  /// 全局Logger实例
  Logger? _logger;
  
  /// 获取Logger实例
  Logger get logger {
    _logger ??= _initLogger();
    return _logger!;
  }
  
  /// 初始化Logger
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
      filter: ProductionFilter(), // 使用生产环境过滤器
    );
  }
  
  /// 重置Logger实例
  void resetLogger() {
    _logger?.close();
    _logger = _initLogger();
  }
  
  /// 设置日志级别
  void setLogLevel(Level level) {
    Logger.level = level;
  }
}