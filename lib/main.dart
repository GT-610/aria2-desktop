import 'package:flutter/material.dart';
import 'app.dart';
import 'utils/logging/log_manager.dart';
import 'services/system_tray_service.dart';

void main() async {
  // Ensure all platform initializations are complete
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging system
  LogManager();

  // Initialize window manager
  await WindowManagerService().initialize();

  // Initialize system tray
  await SystemTrayService().initialize();

  // Run the application
  runApp(const MyApp());
}
