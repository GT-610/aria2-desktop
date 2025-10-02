import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  // 加载设置
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeValue = prefs.getString('themeMode');
      
      if (themeModeValue != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.toString() == 'ThemeMode.$themeModeValue',
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      print('Failed to load settings: $e');
    }
  }

  // 设置主题模式
  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', themeMode.name);
    } catch (e) {
      print('Failed to save theme mode: $e');
    }
  }
}