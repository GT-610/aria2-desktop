import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/logging/log_extensions.dart';
import 'dart:convert' show jsonDecode, jsonEncode;

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
  
  // Settings file name
  final String _settingsFileName = 'settings.json';
  
  // Constructor initialization
  Settings() {
    initLogger();
    logger.i('Settings instance created');
  }
  
  /// Get program data directory
  Directory _getDataDirectory() {
    // Get the executable path
    String executablePath = Platform.resolvedExecutable;
    Directory executableDir = Directory(executablePath).parent;
    
    // Data directory: data/config relative to executable
    String dataDirPath = '${executableDir.path}/data';
    Directory dataDir = Directory(dataDirPath);
    if (!dataDir.existsSync()) {
      logger.d('Creating data directory: $dataDirPath');
      dataDir.createSync(recursive: true);
    }
    
    return dataDir;
  }
  
  /// Get settings file path
  String _getSettingsFilePath() {
    final dataDir = _getDataDirectory();
    final configDir = Directory('${dataDir.path}/config');
    if (!configDir.existsSync()) {
      logger.d('Creating config directory: ${configDir.path}');
      configDir.createSync(recursive: true);
    }
    return '${configDir.path}/$_settingsFileName';
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
  
  // Load all settings from JSON file
  Future<void> loadSettings() async {
    try {
      logger.i('Loading settings from JSON file...');
      final filePath = _getSettingsFilePath();
      final file = File(filePath);
      
      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        final settingsMap = jsonDecode(jsonString);
        
        // Global settings
        _autoStart = settingsMap['autoStart'] ?? false;
        _minimizeToTray = settingsMap['minimizeToTray'] ?? true;
        
        // Appearance settings
        final themeModeValue = settingsMap['themeMode'];
        if (themeModeValue != null) {
          _themeMode = ThemeMode.values.firstWhere(
            (e) => e.name == themeModeValue,
            orElse: () => ThemeMode.system,
          );
        }
        
        final colorCode = settingsMap['primaryColor'];
        if (colorCode != null) {
          try {
            _primaryColor = Color(int.parse(colorCode));
          } catch (e) {
            logger.w('Invalid color code, using default', error: e);
            _primaryColor = Colors.blue;
          }
        }
        
        _customColorCode = settingsMap['customColorCode'];
        
        // Log settings
        final logLevelValue = settingsMap['logLevel'];
        if (logLevelValue != null) {
          _logLevel = LogLevel.values.firstWhere(
            (e) => e.name == logLevelValue,
            orElse: () => LogLevel.info,
          );
        }
        
        _saveLogsToFile = settingsMap['saveLogsToFile'] ?? true;
        
        logger.i('Settings loaded successfully from $filePath');
      } else {
        logger.d('Settings file does not exist, applying default settings');
        _applyDefaultSettings();
      }
      
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
  
  // Save all settings to JSON file
  Future<void> _saveAllSettings() async {
    try {
      final filePath = _getSettingsFilePath();
      final file = File(filePath);
      
      final settingsMap = {
        'autoStart': _autoStart,
        'minimizeToTray': _minimizeToTray,
        'themeMode': _themeMode.name,
        'primaryColor': _primaryColor.value.toString(),
        'customColorCode': _customColorCode,
        'logLevel': _logLevel.name,
        'saveLogsToFile': _saveLogsToFile,
      };
      
      final jsonString = jsonEncode(settingsMap);
      await file.writeAsString(jsonString);
      
      logger.i('All settings saved successfully to $filePath');
    } catch (e) {
      logger.e('Failed to save settings', error: e);
    }
  }
  
  // Auto-run on system startup setting
  Future<void> setAutoStart(bool value) async {
    _autoStart = value;
    notifyListeners();
    await _saveAllSettings();
  }
  
  // Minimize to system tray setting
  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    notifyListeners();
    await _saveAllSettings();
  }
  
  // Theme mode setting
  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();
    await _saveAllSettings();
  }
  
  // Theme color setting
  Future<void> setPrimaryColor(Color color, {bool isCustom = false}) async {
    _primaryColor = color;
    _customColorCode = isCustom ? color.value.toString() : null;
    notifyListeners();
    await _saveAllSettings();
    
    if (isCustom) {
      logger.d('Custom primary color saved: $color');
    } else {
      logger.d('Standard primary color saved: $color');
    }
  }
  
  // Log level setting
  Future<void> setLogLevel(LogLevel level) async {
    _logLevel = level;
    notifyListeners();
    await _saveAllSettings();
  }
  
  // Save logs to file setting
  Future<void> setSaveLogsToFile(bool value) async {
    _saveLogsToFile = value;
    notifyListeners();
    await _saveAllSettings();
  }
}