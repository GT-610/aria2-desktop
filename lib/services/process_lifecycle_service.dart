import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/logging.dart';

/// Bridges process ownership checks to the desktop runner.
///
/// Windows uses a named mutex to ensure only one Setsuna process manages the
/// built-in aria2 instance and a kill-on-close Job Object to prevent orphaned
/// child processes. Other platforms currently have no bundled aria2 binary,
/// so they use the safe no-op fallback.
class ProcessLifecycleService with Loggable {
  ProcessLifecycleService({
    MethodChannel? channel,
    @visibleForTesting bool? isWindows,
  }) : _channel = channel ?? const MethodChannel('setsuna/process_lifecycle'),
       _isWindows = isWindows ?? Platform.isWindows;

  static final ProcessLifecycleService instance = ProcessLifecycleService();

  final MethodChannel _channel;
  final bool _isWindows;

  Future<bool> canManageBuiltinProcess() async {
    if (!_isWindows) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('ownsEngineLock') ?? false;
    } on MissingPluginException {
      w('Process lifecycle integration is unavailable');
      return true;
    } on PlatformException catch (error, stackTrace) {
      w(
        'Failed to query the built-in aria2 ownership lock',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> attachToAppLifecycle(int pid) async {
    if (!_isWindows) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'attachProcess',
            <String, Object>{'pid': pid},
          ) ??
          false;
    } on MissingPluginException {
      w('Process lifecycle integration is unavailable');
      return false;
    } on PlatformException catch (error, stackTrace) {
      w(
        'Failed to attach aria2 process $pid to the application lifecycle',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> isExpectedProcess(int pid, String executablePath) async {
    if (!_isWindows) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'isExpectedProcess',
            <String, Object>{'pid': pid, 'executablePath': executablePath},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error, stackTrace) {
      w(
        'Failed to validate aria2 process $pid',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<int?> findExpectedProcess({
    required int port,
    required String executablePath,
  }) async {
    if (!_isWindows) {
      return null;
    }
    try {
      return await _channel.invokeMethod<int>(
        'findExpectedProcess',
        <String, Object>{'port': port, 'executablePath': executablePath},
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error, stackTrace) {
      w(
        'Failed to find aria2 on RPC port $port',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
