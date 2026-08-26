import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import '../utils/format_utils.dart';
import '../utils/logging.dart';
import 'aria2_rpc_client.dart';
import 'builtin_instance_service.dart';

class SettingsService extends ChangeNotifier with Loggable {
  // ignore: constant_identifier_names
  static const Duration _RUNTIME_APPLY_TIMEOUT = Duration(seconds: 5);
  Settings? _settings;
  Timer? _scheduleTimer;
  bool _scheduleTickInFlight = false;
  String? _lastAppliedLimitsSignature;
  static const int _indefiniteSeedTimeMinutes = 525600;

  /// Starts the passive speed-schedule ticker. Every tick re-evaluates the
  /// effective limits; whenever they change (window entered/left, toggle
  /// flipped) the built-in instance receives a live update. The user's
  /// configured values and switches are never modified by the ticker.
  void ensureScheduleTicker() {
    _scheduleTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(evaluateScheduleTick());
    });
    unawaited(evaluateScheduleTick());
  }

  @visibleForTesting
  Future<void> evaluateScheduleTick() async {
    if (_scheduleTickInFlight) {
      return;
    }
    _scheduleTickInFlight = true;
    try {
      final settings = _settings;
      if (settings == null || !settings.isLoaded) {
        return;
      }
      final limits = settings.effectiveOverallLimits();
      final signature = _currentLimitsSignature();
      if (signature == _lastAppliedLimitsSignature) {
        return;
      }

      final builtinService = BuiltinInstanceService();
      if (!builtinService.isRunning()) {
        // Nothing running to push to; clear so the next start applies fresh.
        _lastAppliedLimitsSignature = null;
        return;
      }

      final applied = await applySettingsToBuiltin();
      _lastAppliedLimitsSignature = applied ? signature : null;
      if (applied) {
        i(
          'Speed limits updated by schedule: '
          'down=${limits.download}, up=${limits.upload}',
        );
      }
    } finally {
      _scheduleTickInFlight = false;
    }
  }

  void initialize(Settings settings) {
    _settings = settings;
    _lastAppliedLimitsSignature = null;
    BuiltinInstanceService().bindSettings(settings);
    ensureScheduleTicker();
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
    super.dispose();
  }

  @visibleForTesting
  Map<String, dynamic> convertSettingsToRuntimeAria2Options() {
    if (_settings == null) {
      w(
        'Cannot convert runtime settings to aria2 options because settings are not initialized',
      );
      return {};
    }

    final settings = _settings!;
    final limits = settings.effectiveOverallLimits();
    final options = <String, dynamic>{
      'max-concurrent-downloads': settings.maxConcurrentDownloads.toString(),
      'max-connection-per-server': settings.maxConnectionPerServer.toString(),
      'split': settings.split.toString(),
      'continue': settings.continueDownloads.toString(),
      // Effective values honor the master switch and schedule window; 0
      // means unlimited for aria2.
      'max-overall-download-limit': formatSpeedLimitOption(limits.download),
      'max-overall-upload-limit': formatSpeedLimitOption(limits.upload),
      'bt-save-metadata': settings.btSaveMetadata.toString(),
      'bt-require-crypto': settings.btForceEncryption.toString(),
      'seed-time':
          (settings.keepSeeding
                  ? _indefiniteSeedTimeMinutes
                  : settings.seedTime)
              .toString(),
      'seed-ratio': (settings.keepSeeding ? 0.0 : settings.seedRatio)
          .toString(),
      'bt-tracker': settings.btTracker,
      'bt-exclude-tracker': settings.btExcludeTracker,
      'auto-file-renaming': settings.autoFileRenaming.toString(),
      'allow-overwrite': settings.allowOverwrite.toString(),
      // Send proxy fields even when empty so clearing them removes the
      // running instance's previous proxy configuration.
      'all-proxy': settings.proxyEnabled ? settings.allProxy : '',
      'no-proxy': settings.proxyEnabled ? settings.noProxy : '',
      'user-agent': settings.userAgent,
    };

    if (settings.downloadDir.trim().isNotEmpty) {
      options['dir'] = settings.downloadDir.trim();
    }

    return options;
  }

  String _currentLimitsSignature() {
    final limits = _settings?.effectiveOverallLimits();
    return '${limits?.download}/${limits?.upload}';
  }

  /// Applies runtime settings to the built-in instance. When [rpcClient] is
  /// provided it is reused and must be closed by its owner; otherwise a
  /// dedicated client is created and closed here.
  Future<bool> applySettingsToBuiltin({Aria2RpcClient? rpcClient}) async {
    if (_settings == null) {
      w(
        'Cannot apply built-in aria2 settings because settings are not initialized',
      );
      return false;
    }

    final builtinInstance = BuiltinInstanceService().getBuiltinInstanceConfig();
    final ownedClient = rpcClient == null;
    final client =
        rpcClient ??
        Aria2RpcClient(
          builtinInstance,
          requestTimeout: _RUNTIME_APPLY_TIMEOUT,
          maximumAttempts: 1,
        );

    try {
      final result = await client
          .setGlobalOption(convertSettingsToRuntimeAria2Options())
          .timeout(_RUNTIME_APPLY_TIMEOUT);
      if (result) {
        _lastAppliedLimitsSignature = _currentLimitsSignature();
        i('Applied runtime settings to the built-in aria2 instance');
      } else {
        w(
          'Built-in aria2 rejected the runtime settings update without throwing an exception',
        );
      }
      return result;
    } catch (err, stackTrace) {
      e(
        'Failed to apply settings to built-in Aria2',
        error: err,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      if (ownedClient) {
        await client.close();
      }
    }
  }
}
