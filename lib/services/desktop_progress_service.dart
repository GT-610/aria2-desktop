import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../pages/download_page/enums.dart';
import '../pages/download_page/models/download_task.dart';
import '../utils/logging.dart';

double calculateDesktopProgress({
  required bool enabled,
  required List<DownloadTask> tasks,
}) {
  if (!enabled) {
    return -1;
  }

  final activeDownloads = tasks.where(
    (task) =>
        task.status == DownloadStatus.active &&
        task.taskStatus == 'active' &&
        !task.isSeeder,
  );
  var totalBytes = 0;
  var completedBytes = 0;
  var hasActiveDownloads = false;
  for (final task in activeDownloads) {
    hasActiveDownloads = true;
    totalBytes += task.totalLengthBytes;
    completedBytes += task.completedLengthBytes;
  }

  if (!hasActiveDownloads) {
    return -1;
  }
  if (totalBytes <= 0) {
    return 2;
  }
  return (completedBytes / totalBytes).clamp(0.0, 1.0);
}

class DesktopProgressService with Loggable {
  DesktopProgressService({
    Future<void> Function(double progress)? setProgress,
    @visibleForTesting bool? isSupported,
  }) : _setProgress = setProgress ?? _platformSetProgress,
       _isSupported = isSupported ?? (Platform.isWindows || Platform.isMacOS);

  static const MethodChannel _windowsChannel = MethodChannel(
    'setsuna/desktop_progress',
  );

  static Future<void> _platformSetProgress(double progress) {
    if (Platform.isWindows) {
      return _windowsChannel.invokeMethod<void>('setProgress', <String, Object>{
        'progress': progress,
      });
    }
    return windowManager.setProgressBar(progress);
  }

  final Future<void> Function(double progress) _setProgress;
  final bool _isSupported;
  double? _desiredProgress;
  double? _appliedProgress;
  Future<void>? _syncLoop;

  Future<void> synchronize({
    required bool enabled,
    required List<DownloadTask> tasks,
  }) {
    if (!_isSupported) {
      return Future<void>.value();
    }

    _desiredProgress = calculateDesktopProgress(enabled: enabled, tasks: tasks);
    final activeLoop = _syncLoop;
    if (activeLoop != null) {
      return activeLoop;
    }

    final loop = _runSyncLoop();
    _syncLoop = loop;
    return loop;
  }

  Future<void> clear() {
    return synchronize(enabled: false, tasks: const <DownloadTask>[]);
  }

  Future<void> _runSyncLoop() async {
    while (_desiredProgress != _appliedProgress) {
      final progress = _desiredProgress!;
      try {
        await _setProgress(progress);
      } on MissingPluginException {
        w('Desktop progress integration is unavailable');
      } on PlatformException catch (error, stackTrace) {
        w(
          'Failed to update desktop download progress',
          error: error,
          stackTrace: stackTrace,
        );
      }
      _appliedProgress = progress;
    }
    _syncLoop = null;
  }
}
