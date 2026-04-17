import 'package:flutter/material.dart';
import 'app.dart';
import 'models/settings.dart';
import 'services/protocol_integration_service.dart';
import 'services/startup_integration_service.dart';
import 'services/system_tray_service.dart';

void main(List<String> args) async {
  // Ensure all platform initializations are complete
  WidgetsFlutterBinding.ensureInitialized();

  ProtocolIntegrationService().captureInitialArguments(args);

  final settings = Settings();
  await settings.loadSettings();
  try {
    await StartupIntegrationService().initialize();
  } catch (e, stackTrace) {
    debugPrint('Failed to initialize run-at-startup integration: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  // Initialize window manager
  await WindowManagerService().initialize(hideTitleBar: settings.hideTitleBar);

  // Run the application
  runApp(const MyApp());
}
