import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logging/log_extensions.dart';

class Settings extends ChangeNotifier with Loggable {
  // Constructor to initialize logger
  Settings() {
    initLogger();
  }
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = Colors.blue; // Default primary color
  String? _customColorCode; // Store custom color code if used

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  String? get customColorCode => _customColorCode;

  // Load settings from SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeValue = prefs.getString('themeMode');
      final colorCode = prefs.getString('primaryColor');
      final customCode = prefs.getString('customColorCode');
      
      if (themeModeValue != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.toString() == 'ThemeMode.$themeModeValue',
          orElse: () => ThemeMode.system,
        );
      }
      
      if (colorCode != null) {
        try {
          _primaryColor = Color(int.parse(colorCode));
        } catch (e) {
          _primaryColor = Colors.blue;
        }
      }
      
      _customColorCode = customCode;
    } catch (e) {
      logger.e('Failed to load settings', error: e);
    }
  }

  // Update and save theme mode setting
  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', themeMode.name);
      logger.d('Theme mode saved: ${themeMode.name}');
    } catch (e) {
      logger.e('Failed to save theme mode', error: e);
    }
  }
  
  // Update and save primary color setting
  Future<void> setPrimaryColor(Color color, {bool isCustom = false}) async {
    _primaryColor = color;
    _customColorCode = isCustom ? color.toARGB32().toString() : null;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('primaryColor', color.toARGB32().toString());
      if (isCustom) {
        await prefs.setString('customColorCode', color.toARGB32().toString());
        logger.d('Custom primary color saved: $color');
      } else {
        await prefs.remove('customColorCode');
        logger.d('Standard primary color saved: $color');
      }
    } catch (e) {
      logger.e('Failed to save primary color', error: e);
    }
  }
}