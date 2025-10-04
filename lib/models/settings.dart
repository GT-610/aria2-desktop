import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoConnectLastInstance = false;

  ThemeMode get themeMode => _themeMode;
  bool get autoConnectLastInstance => _autoConnectLastInstance;

  // Load settings from SharedPreferences
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
      
      _autoConnectLastInstance = prefs.getBool('autoConnectLastInstance') ?? false;
    } catch (e) {
      print('Failed to load settings: $e');
    }
  }

  // Update and save theme mode setting
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
  
  // Update and save auto-connect setting
  Future<void> setAutoConnectLastInstance(bool value) async {
    _autoConnectLastInstance = value;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoConnectLastInstance', value);
    } catch (e) {
      print('Failed to save auto connect setting: $e');
    }
  }
}