import 'package:flutter/foundation.dart';

import '../models/settings.dart';
import '../utils/format_utils.dart';
import '../utils/logging.dart';
import 'aria2_rpc_client.dart';
import 'builtin_instance_service.dart';

class SettingsService extends ChangeNotifier with Loggable {
  Settings? _settings;
  static const int _indefiniteSeedTimeMinutes = 525600;

  void initialize(Settings settings) {
    _settings = settings;
  }

  Map<String, dynamic> _convertSettingsToRuntimeAria2Options() {
    if (_settings == null) {
      w(
        'Cannot convert runtime settings to aria2 options because settings are not initialized',
      );
      return {};
    }

    final settings = _settings!;
    final options = <String, dynamic>{
      'max-concurrent-downloads': settings.maxConcurrentDownloads.toString(),
      'max-connection-per-server': settings.maxConnectionPerServer.toString(),
      'split': settings.split.toString(),
      'continue': settings.continueDownloads.toString(),
      'max-overall-download-limit': formatSpeedLimitOption(
        settings.maxOverallDownloadLimit,
      ),
      'max-overall-upload-limit': formatSpeedLimitOption(
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

  Future<bool> applySettingsToBuiltin() async {
    if (_settings == null) {
      w(
        'Cannot apply built-in aria2 settings because settings are not initialized',
      );
      return false;
    }

    final builtinInstance = BuiltinInstanceService().getBuiltinInstanceConfig();
    final client = Aria2RpcClient(builtinInstance);

    try {
      final result = await client.setGlobalOption(
        _convertSettingsToRuntimeAria2Options(),
      );
      if (result) {
        i('Applied runtime settings to the built-in aria2 instance');
      } else {
        w(
          'Built-in aria2 rejected the runtime settings update without throwing an exception',
        );
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
        'max-overall-download-limit': formatSpeedLimitOption(
          _settings!.maxOverallDownloadLimit,
        ),
        'max-overall-upload-limit': formatSpeedLimitOption(
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
