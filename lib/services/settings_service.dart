import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/settings.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';

class SettingsService extends ChangeNotifier with Loggable {
  Settings? _settings;
  Aria2Instance? _currentInstance;
  Aria2RpcClient? _rpcClient;

  SettingsService() {}

  void initialize(Settings settings, Aria2Instance? currentInstance) {
    _settings = settings;
    _currentInstance = currentInstance;
    if (currentInstance != null) {
      _rpcClient = Aria2RpcClient(currentInstance);
    }
  }

  void updateInstance(Aria2Instance? instance) {
    _rpcClient?.close();
    _currentInstance = instance;
    if (instance != null) {
      _rpcClient = Aria2RpcClient(instance);
    } else {
      _rpcClient = null;
    }
  }

  Map<String, dynamic> _convertSettingsToAria2Options() {
    if (_settings == null) {
      w('Settings is null, cannot convert to Aria2 options');
      return {};
    }

    final options = <String, dynamic>{};

    // Transfer settings
    options['max-concurrent-downloads'] =
        _settings!.maxConcurrentDownloads.toString();
    options['max-connection-per-server'] =
        _settings!.maxConnectionPerServer.toString();
    options['split'] = _settings!.split.toString();
    options['continue'] = _settings!.continueDownloads.toString();

    // Speed settings
    if (_settings!.maxOverallDownloadLimit > 0) {
      options['max-overall-download-limit'] =
          _settings!.maxOverallDownloadLimit.toString();
    } else {
      options['max-overall-download-limit'] = '0';
    }
    if (_settings!.maxOverallUploadLimit > 0) {
      options['max-overall-upload-limit'] =
          _settings!.maxOverallUploadLimit.toString();
    } else {
      options['max-overall-upload-limit'] = '0';
    }

    // BT settings
    options['bt-save-metadata'] = _settings!.btSaveMetadata.toString();
    options['bt-force-encryption'] = _settings!.btForceEncryption.toString();
    options['bt-load-saved-metadata'] =
        _settings!.btLoadSavedMetadata.toString();
    options['seed-time'] = _settings!.seedTime.toString();
    options['seed-ratio'] = _settings!.seedRatio.toString();
    options['bt-exclude-tracker'] = _settings!.btExcludeTracker;

    // Advanced settings
    if (_settings!.allProxy.isNotEmpty) {
      options['all-proxy'] = _settings!.allProxy;
    }
    if (_settings!.noProxy.isNotEmpty) {
      options['no-proxy'] = _settings!.noProxy;
    }
    options['dht-listen-port'] = _settings!.dhtListenPort.toString();
    options['enable-dht6'] = _settings!.enableDht6.toString();
    options['auto-file-renaming'] = _settings!.autoFileRenaming.toString();
    options['allow-overwrite'] = _settings!.allowOverwrite.toString();
    options['user-agent'] = _settings!.userAgent;

    d('Converted settings to Aria2 options: $options');
    return options;
  }

  Future<bool> applySettingsToAria2() async {
    if (_rpcClient == null) {
      w('No RPC client available, cannot apply settings');
      return false;
    }

    if (_currentInstance == null) {
      w('No connected instance, cannot apply settings');
      return false;
    }

    try {
      final options = _convertSettingsToAria2Options();
      i('Applying settings to Aria2 instance: ${_currentInstance!.name}');

      final result = await _rpcClient!.setGlobalOption(options);

      if (result) {
        i('Settings applied successfully to Aria2');
      } else {
        w('Failed to apply settings to Aria2');
      }

      return result;
    } catch (err, stackTrace) {
      this.e(
        'Failed to apply settings to Aria2',
        error: err,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> applySpeedSettings() async {
    if (_rpcClient == null || _settings == null) {
      return false;
    }

    try {
      final options = <String, dynamic>{};

      if (_settings!.maxOverallDownloadLimit > 0) {
        options['max-overall-download-limit'] =
            _settings!.maxOverallDownloadLimit;
      } else {
        options['max-overall-download-limit'] = '0';
      }
      if (_settings!.maxOverallUploadLimit > 0) {
        options['max-overall-upload-limit'] = _settings!.maxOverallUploadLimit;
      } else {
        options['max-overall-upload-limit'] = '0';
      }

      i('Applying speed settings to Aria2');
      final result = await _rpcClient!.setGlobalOption(options);
      return result;
    } catch (err, stackTrace) {
      this.e(
        'Failed to apply speed settings',
        error: err,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  void dispose() {
    _rpcClient?.close();
    super.dispose();
  }
}
