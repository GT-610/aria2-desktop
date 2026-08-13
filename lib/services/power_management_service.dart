import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../pages/download_page/enums.dart';
import '../pages/download_page/models/download_task.dart';
import '../utils/logging.dart';

bool shouldPreventSystemSleep({
  required bool enabled,
  required List<DownloadTask> tasks,
}) {
  if (!enabled) {
    return false;
  }
  return tasks.any(
    (task) =>
        task.status == DownloadStatus.active &&
        task.taskStatus == 'active' &&
        !task.isSeeder,
  );
}

class PowerManagementService with Loggable {
  PowerManagementService({
    MethodChannel? channel,
    @visibleForTesting bool? isSupported,
    @visibleForTesting bool? isLinux,
  }) : _channel = channel ?? const MethodChannel('setsuna/power_management'),
       _isSupported =
           isSupported ??
           (Platform.isWindows || Platform.isMacOS || Platform.isLinux),
       _isLinux = isLinux ?? Platform.isLinux;

  final MethodChannel _channel;
  final bool _isSupported;
  final bool _isLinux;
  final _LinuxSleepInhibitor _linuxInhibitor = _LinuxSleepInhibitor();
  bool? _desiredEnabled;
  bool? _appliedEnabled;
  Future<void>? _syncLoop;

  Future<void> synchronize({
    required bool enabled,
    required List<DownloadTask> tasks,
  }) {
    if (!_isSupported) {
      return Future<void>.value();
    }
    _desiredEnabled = shouldPreventSystemSleep(enabled: enabled, tasks: tasks);
    final activeLoop = _syncLoop;
    if (activeLoop != null) {
      return activeLoop;
    }

    final loop = Future<void>.microtask(_runSyncLoop);
    _syncLoop = loop;
    return loop;
  }

  Future<void> release() {
    return synchronize(enabled: false, tasks: const <DownloadTask>[]);
  }

  Future<void> _runSyncLoop() async {
    try {
      while (_desiredEnabled != _appliedEnabled) {
        final enabled = _desiredEnabled!;
        try {
          if (_isLinux) {
            await _linuxInhibitor.setEnabled(enabled);
          } else {
            await _channel.invokeMethod<void>(
              'setPreventSleep',
              <String, Object>{'enabled': enabled},
            );
          }
        } on MissingPluginException {
          w('Power management integration is unavailable');
        } on PlatformException catch (error, stackTrace) {
          w(
            'Failed to update download sleep prevention',
            error: error,
            stackTrace: stackTrace,
          );
        } catch (error, stackTrace) {
          w(
            'Failed to update download sleep prevention',
            error: error,
            stackTrace: stackTrace,
          );
        }
        _appliedEnabled = enabled;
      }
    } finally {
      _syncLoop = null;
    }
  }
}

class _LinuxSleepInhibitor {
  RandomAccessFile? _inhibitorFile;
  DBusClient? _client;

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _acquire();
    } else {
      await _release();
    }
  }

  Future<void> _acquire() async {
    if (_inhibitorFile != null) {
      return;
    }

    final client = DBusClient.system();
    try {
      final loginManager = DBusRemoteObject(
        client,
        name: 'org.freedesktop.login1',
        path: DBusObjectPath('/org/freedesktop/login1'),
      );
      final response = await loginManager
          .callMethod('org.freedesktop.login1.Manager', 'Inhibit', <DBusValue>[
            const DBusString('idle'),
            const DBusString('Setsuna'),
            const DBusString('Active downloads in progress'),
            const DBusString('block'),
          ], replySignature: DBusSignature.unixFd);
      _inhibitorFile = response.returnValues.single.asUnixFd().toFile();
      _client = client;
    } catch (_) {
      await client.close();
      rethrow;
    }
  }

  Future<void> _release() async {
    final file = _inhibitorFile;
    final client = _client;
    _inhibitorFile = null;
    _client = null;
    await file?.close();
    await client?.close();
  }
}
