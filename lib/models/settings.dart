import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logging/log_extensions.dart';

// 日志级别枚举
enum LogLevel {
  debug,
  info,
  warning,
  error
}

class Settings extends ChangeNotifier with Loggable {
  // 全局设置
  bool _autoStart = false; // 系统启动时自动运行
  bool _minimizeToTray = true; // 最小化到系统托盘
  
  // 外观设置
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = Colors.blue; // 默认主题色
  String? _customColorCode; // 自定义颜色代码
  
  // 日志设置
  LogLevel _logLevel = LogLevel.info; // 日志级别
  bool _saveLogsToFile = true; // 保存日志到文件
  
  // 构造函数初始化
  Settings() {
    initLogger();
    logger.i('Settings instance created');
  }
  
  // Getters
  bool get autoStart => _autoStart;
  bool get minimizeToTray => _minimizeToTray;
  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  String? get customColorCode => _customColorCode;
  LogLevel get logLevel => _logLevel;
  bool get saveLogsToFile => _saveLogsToFile;
  String get logLevelString => _logLevel.name;
  
  // 从SharedPreferences加载所有设置
  Future<void> loadSettings() async {
    try {
      logger.i('Loading settings from storage...');
      final prefs = await SharedPreferences.getInstance();
      
      // 全局设置
      _autoStart = prefs.getBool('autoStart') ?? false;
      _minimizeToTray = prefs.getBool('minimizeToTray') ?? true;
      
      // 外观设置
      final themeModeValue = prefs.getString('themeMode');
      if (themeModeValue != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.name == themeModeValue,
          orElse: () => ThemeMode.system,
        );
      }
      
      final colorCode = prefs.getString('primaryColor');
      if (colorCode != null) {
        try {
          _primaryColor = Color(int.parse(colorCode)); // Note: For Flutter 3.16+, use Color.fromARGB32(int.parse(colorCode))
        } catch (e) {
          logger.w('Invalid color code, using default', error: e);
          _primaryColor = Colors.blue;
        }
      }
      
      _customColorCode = prefs.getString('customColorCode');
      
      // 日志设置
      final logLevelValue = prefs.getString('logLevel');
      if (logLevelValue != null) {
        _logLevel = LogLevel.values.firstWhere(
          (e) => e.name == logLevelValue,
          orElse: () => LogLevel.info,
        );
      }
      
      _saveLogsToFile = prefs.getBool('saveLogsToFile') ?? true;
      
      logger.i('Settings loaded successfully');
      notifyListeners();
    } catch (e) {
      logger.e('Failed to load settings', error: e);
      // 应用默认设置
      _applyDefaultSettings();
    }
  }
  
  // 应用默认设置
  void _applyDefaultSettings() {
    logger.i('Applying default settings');
    _autoStart = false;
    _minimizeToTray = true;
    _themeMode = ThemeMode.system;
    _primaryColor = Colors.blue;
    _customColorCode = null;
    _logLevel = LogLevel.info;
    _saveLogsToFile = true;
    notifyListeners();
  }
  
  // 异步保存设置的通用方法
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
      
      logger.d('Setting saved: $key = $value');
    } catch (e) {
      logger.e('Failed to save setting: $key', error: e);
    }
  }
  
  // 系统启动时自动运行设置
  Future<void> setAutoStart(bool value) async {
    _autoStart = value;
    notifyListeners();
    await _saveSetting('autoStart', value);
  }
  
  // 最小化到系统托盘设置
  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    notifyListeners();
    await _saveSetting('minimizeToTray', value);
  }
  
  // 主题模式设置
  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();
    await _saveSetting('themeMode', themeMode.name);
  }
  
  // 主题色设置
  Future<void> setPrimaryColor(Color color, {bool isCustom = false}) async {
    _primaryColor = color;
    _customColorCode = isCustom ? color.toARGB32().toString() : null;
    notifyListeners();
    
    await _saveSetting('primaryColor', color.toARGB32().toString());
    
    if (isCustom) {
      await _saveSetting('customColorCode', color.toARGB32().toString());
      logger.d('Custom primary color saved: $color');
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('customColorCode');
        logger.d('Standard primary color saved: $color');
      } catch (e) {
        logger.e('Failed to remove custom color code', error: e);
      }
    }
  }
  
  // 日志级别设置
  Future<void> setLogLevel(LogLevel level) async {
    _logLevel = level;
    notifyListeners();
    await _saveSetting('logLevel', level.name);
  }
  
  // 保存日志到文件设置
  Future<void> setSaveLogsToFile(bool value) async {
    _saveLogsToFile = value;
    notifyListeners();
    await _saveSetting('saveLogsToFile', value);
  }
}