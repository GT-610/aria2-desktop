import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import '../utils/logging.dart';
import 'aria2_rpc_client.dart';
import 'builtin_instance_service.dart';

class SettingsService extends ChangeNotifier with Loggable {
  Settings? _settings;
  static const int _indefiniteSeedTimeMinutes = 525600;

  void initialize(Settings settings) {
    _settings = settings;
  }

  String _formatSpeedLimitOption(int value) {
    return value > 0 ? '${value}K' : '0';
  }

  Map<String, dynamic> _convertSettingsToRuntimeAria2Options() {
    if (_settings == null) {
      w('Settings is null, cannot convert runtime settings to Aria2 options');
      return {};
    }

    final settings = _settings!;
    final options = <String, dynamic>{
      'max-concurrent-downloads': settings.maxConcurrentDownloads.toString(),
      'max-connection-per-server': settings.maxConnectionPerServer.toString(),
      'split': settings.split.toString(),
      'continue': settings.continueDownloads.toString(),
      'max-overall-download-limit': _formatSpeedLimitOption(
        settings.maxOverallDownloadLimit,
      ),
      'max-overall-upload-limit': _formatSpeedLimitOption(
        settings.maxOverallUploadLimit,
      ),
      'bt-save-metadata': settings.btSaveMetadata.toString(),
      'bt-require-crypto': settings.btForceEncryption.toString(),
      'seed-time':
          (settings.keepSeeding
                  ? _indefiniteSeedTimeMinutes
                  : settings.seedTime)
              .toString(),
      'seed-ratio': (settings.keepSeeding ? 0.0 : settings.seedRatio)
          .toString(),
      'bt-exclude-tracker': settings.btExcludeTracker,
      'auto-file-renaming': settings.autoFileRenaming.toString(),
      'allow-overwrite': settings.allowOverwrite.toString(),
      'user-agent': settings.userAgent,
    };

    if (settings.allProxy.isNotEmpty) {
      options['all-proxy'] = settings.allProxy;
    }
    if (settings.noProxy.isNotEmpty) {
      options['no-proxy'] = settings.noProxy;
    }

    return options;
  }

  Future<bool> applySettingsToBuiltin() async {
    if (_settings == null) {
      w('Settings is null, cannot apply settings');
      return false;
    }

    final builtinInstance = BuiltinInstanceService().getBuiltinInstanceConfig();
    final client = Aria2RpcClient(builtinInstance);

    try {
      final result = await client.setGlobalOption(
        _convertSettingsToRuntimeAria2Options(),
      );
      if (result) {
        i('Settings applied successfully to built-in Aria2');
      } else {
        w('Failed to apply settings to built-in Aria2');
      }
      return result;
    } catch (err, stackTrace) {
      this.e(
        'Failed to apply settings to built-in Aria2',
        error: err,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      client.close();
    }
  }

  Future<bool> applySpeedSettingsToBuiltin() async {
    if (_settings == null) {
      return false;
    }

    final builtinInstance = BuiltinInstanceService().getBuiltinInstanceConfig();
    final client = Aria2RpcClient(builtinInstance);

    try {
      final options = <String, dynamic>{
        'max-overall-download-limit': _formatSpeedLimitOption(
          _settings!.maxOverallDownloadLimit,
        ),
        'max-overall-upload-limit': _formatSpeedLimitOption(
          _settings!.maxOverallUploadLimit,
        ),
      };
      return await client.setGlobalOption(options);
    } catch (err, stackTrace) {
      this.e(
        'Failed to apply speed settings to built-in Aria2',
        error: err,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      client.close();
    }
  }
}
