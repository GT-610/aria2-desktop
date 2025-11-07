import 'package:logger/logger.dart';

/// 日志系统配置类
class LogConfig {
  /// 日志级别配置
  static const Level logLevel = Level.verbose;
  
  /// 是否在控制台显示颜色
  static const bool useColors = true;
  
  /// 是否显示方法调用信息
  static const int methodCount = 2;
  
  /// 错误时显示的方法调用信息数量
  static const int errorMethodCount = 8;
  
  /// 日志输出行宽
  static const int lineLength = 120;
  
  /// 是否显示emoji
  static const bool printEmojis = true;
  
  /// 日期时间格式函数
  static String Function(DateTime) dateTimeFormat = (DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')} (+${diff.inMilliseconds}ms)';
  };
}