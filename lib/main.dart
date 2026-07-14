import 'package:flutter/material.dart';
import 'app.dart';
import 'models/settings.dart';
import 'services/protocol_integration_service.dart';
import 'services/startup_integration_service.dart';
import 'services/system_tray_service.dart';
import 'services/data_migration_service.dart';
import 'services/core_provisioning_service.dart';
import 'utils/app_paths.dart';
import 'utils/logging.dart';

void main(List<String> args) async {
  // Ensure all platform initializations are complete
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.initialize();
  initializeAppLogging();

  final logger = taggedLogger('Main');
  try {
    await DataMigrationService().migrateLegacyPortableData();
    await CoreProvisioningService().ensureDefaultConfiguration();
  } catch (e, stackTrace) {
    logger.e(
      'Failed to migrate legacy application data',
      error: e,
      stackTrace: stackTrace,
    );
  }

  ProtocolIntegrationService().captureInitialArguments(args);

  final settings = Settings();
  await settings.loadSettings();
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
