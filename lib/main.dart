import 'package:flutter/material.dart';
import 'app.dart';
import 'services/system_tray_service.dart';

void main() async {
  // Ensure all platform initializations are complete
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager
  await WindowManagerService().initialize();

  // Initialize system tray
  await SystemTrayService().initialize();

  // Run the application
  runApp(const MyApp());
}
