import 'package:flutter/material.dart';
import 'app.dart';
import 'services/protocol_integration_service.dart';
import 'services/system_tray_service.dart';

void main(List<String> args) async {
  // Ensure all platform initializations are complete
  WidgetsFlutterBinding.ensureInitialized();

  ProtocolIntegrationService().captureInitialArguments(args);

  // Initialize window manager
  await WindowManagerService().initialize();

  // Run the application
  runApp(const MyApp());
}
