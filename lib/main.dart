import 'package:flutter/material.dart';
import 'app.dart';
import 'models/settings.dart';
import 'services/protocol_integration_service.dart';
import 'services/startup_integration_service.dart';
import 'services/system_tray_service.dart';
import 'utils/logging.dart';

void main(List<String> args) async {
  // Ensure all platform initializations are complete
  WidgetsFlutterBinding.ensureInitialized();
  initializeAppLogging();

  ProtocolIntegrationService().captureInitialArguments(args);

  final settings = Settings();
  await settings.loadSettings();
  final logger = taggedLogger('Main');
  try {
    await StartupIntegrationService().initialize();
  } catch (e, stackTrace) {
    logger.e(
      'Failed to initialize run-at-startup integration',
      error: e,
      stackTrace: stackTrace,
    );
  }

  // Initialize window manager
  await WindowManagerService().initialize(hideTitleBar: settings.hideTitleBar);

  // Run the application
  runApp(const MyApp());
}
