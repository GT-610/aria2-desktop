import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../constants/app_branding.dart';
import '../models/settings.dart';
import '../utils/logging.dart';

class StartupIntegrationService with Loggable {
  static final StartupIntegrationService _instance =
      StartupIntegrationService._internal();

  bool _isSetup = false;

  factory StartupIntegrationService() {
    return _instance;
  }

  StartupIntegrationService._internal();

  bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  Future<void> initialize() async {
    if (_isSetup || !isSupported) {
      return;
    }

    launchAtStartup.setup(
      appName: kAppName,
      appPath: Platform.resolvedExecutable,
      packageName: kAppPackageName,
    );
    _isSetup = true;
  }

  Future<void> setEnabled(bool enabled) async {
    if (!isSupported) {
      return;
    }

    await initialize();
    final currentlyEnabled = await launchAtStartup.isEnabled();
    if (currentlyEnabled == enabled) {
      return;
    }

    if (enabled) {
      await launchAtStartup.enable();
      i('Run-at-startup enabled');
      return;
    }

    await launchAtStartup.disable();
    i('Run-at-startup disabled');
  }

  Future<void> reconcileStartupPreference(Settings settings) async {
    if (!isSupported) {
      return;
    }

    await initialize();
    await setEnabled(settings.autoStart);
  }
}
