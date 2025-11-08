import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logging/log_extensions.dart';

// Log level enumeration
enum LogLevel {
  debug,
  info,
  warning,
  error
}

class Settings extends ChangeNotifier with Loggable {
  // Global settings
  bool _autoStart = false; // Auto-run on system startup
  bool _minimizeToTray = true; // Minimize to system tray
  
  // Appearance settings
  ThemeMode _themeMode = ThemeMode.system;// Appearance settings
  // Default theme color
  Color _primaryColor = Colors.blue; // Default theme color
  String? _customColorCode; // Custom color code 
  // Log settings
  LogLevel _logLevel = LogLevel.info; // Log level
  bool _saveLogsToFile = true; // Save logs to file
  
  // Constructor initialization
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
  
  // Load all settings from SharedPreferences
  Future<void> loadSettings() async {
    try {
      logger.i('Loading settings from storage...');
      final prefs = await SharedPreferences.getInstance();
      
      // Global settings
      _autoStart = prefs.getBool('autoStart') ?? false;
      _minimizeToTray = prefs.getBool('minimizeToTray') ?? true;
      
      // Appearance settings
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
      
      // Log settings
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
      // Apply default settings
      _applyDefaultSettings();
    }
  }
  
  // Apply default settings
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
  
  // Generic method to save settings asynchronously
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
  
  // Auto-run on system startup setting
  Future<void> setAutoStart(bool value) async {
    _autoStart = value;
    notifyListeners();
    await _saveSetting('autoStart', value);
  }
  
  // Minimize to system tray setting
  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    notifyListeners();
    await _saveSetting('minimizeToTray', value);
  }
  
  // Theme mode setting
  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();
    await _saveSetting('themeMode', themeMode.name);
  }
  
  // Theme color setting
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
  
  // Log level setting
  Future<void> setLogLevel(LogLevel level) async {
    _logLevel = level;
    notifyListeners();
    await _saveSetting('logLevel', level.name);
  }
  
  // Save logs to file setting
  Future<void> setSaveLogsToFile(bool value) async {
    _saveLogsToFile = value;
    notifyListeners();
    await _saveSetting('saveLogsToFile', value);
  }
}