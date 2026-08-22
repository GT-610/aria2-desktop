import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../models/settings.dart';
import '../../../services/aria2_rpc_client.dart';
import '../../../services/download_data_service.dart';
import '../../../services/instance_manager.dart';
import '../../../utils/logging.dart';
import '../enums.dart';
import '../models/download_task.dart';
import '../utils/task_retry.dart';

final _logger = taggedLogger('DownloadTaskService');

class DeleteTaskResult {
  const DeleteTaskResult({
    required this.removedFromAria2,
    this.fileDeletionErrors = const [],
  });

  final bool removedFromAria2;
  final List<String> fileDeletionErrors;

  bool get hasFileDeletionErrors => fileDeletionErrors.isNotEmpty;
}

class DownloadTaskService with Loggable {
  static const Set<String> _portableRetryOptionKeys = <String>{
    'dir',
    'out',
    'header',
    'split',
    'user-agent',
    'referer',
    'all-proxy',
    'auto-file-renaming',
    'allow-overwrite',
    'max-connection-per-server',
    'continue',
    'select-file',
    'check-integrity',
    'force-save',
  };

  static Future<bool?> promptDeleteDownloadedFiles(
    BuildContext context,
    List<DownloadTask> tasks,
  ) async {
    final localTasks = tasks.where((task) => task.isLocal).toList();
    if (localTasks.isEmpty) {
      return false;
    }

    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteTasks),
          content: Text(l10n.deleteFilesOptionHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.removeOnly),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.removeAndDeleteFiles),
            ),
          ],
        );
      },
    );
  }

  static bool shouldSkipDeleteConfirmation(BuildContext context) {
    return Provider.of<Settings>(context, listen: false).skipDeleteConfirm;
  }

  static Future<DeleteTaskResult> deleteTaskWithClient(
    Aria2RpcClient client,
    DownloadTask task, {
    bool deleteDownloadedFiles = false,
    Future<void> Function()? removeTaskOverride,
    Future<List<String>> Function(DownloadTask task)? deleteFilesOverride,
  }) async {
    if (task.status == DownloadStatus.stopped) {
      if (removeTaskOverride != null) {
        await removeTaskOverride();
      } else {
        await client.removeDownloadResult(task.id);
      }
    } else {
      if (removeTaskOverride != null) {
        await removeTaskOverride();
      } else {
        await client.removeTask(task.id);
      }
    }

    var fileDeletionErrors = const <String>[];
    if (deleteDownloadedFiles && task.isLocal) {
      try {
        fileDeletionErrors = deleteFilesOverride != null
            ? await deleteFilesOverride(task)
            : await _deleteDownloadedFiles(task);
      } catch (error) {
        fileDeletionErrors = ['$error'];
      }
    }

    if (fileDeletionErrors.isNotEmpty) {
      _logger.w(
        'Task ${task.id} was removed from Aria2, but file cleanup had issues: ${fileDeletionErrors.join(', ')}',
      );
    }

    return DeleteTaskResult(
      removedFromAria2: true,
      fileDeletionErrors: fileDeletionErrors,
    );
  }

  /// Single source of truth for the per-status icon shown across the task
  /// list, toolbar, and details dialog.
  static IconData statusIconFor(DownloadTask task) {
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return Icons.pause;
    }

    if (isSeedingTask(task)) {
      return Icons.upload;
    }

    if (task.status == DownloadStatus.stopped &&
        task.taskStatus == 'complete') {
      return Icons.check_circle;
    }

    switch (task.status) {
      case DownloadStatus.active:
        return Icons.file_download;
      case DownloadStatus.waiting:
        return Icons.schedule;
      case DownloadStatus.stopped:
        return Icons.pause_circle;
    }
  }

  /// Single source of truth for the per-status label and color shown across
  /// the task list, toolbar, and details dialog.
  static ({String label, IconData icon, Color color}) getTaskVisuals(
    BuildContext context,
    DownloadTask task,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final String label;
    final Color color;
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      label = l10n.paused;
      color = colorScheme.tertiary;
    } else if (isSeedingTask(task)) {
      label = l10n.seeding;
      color = const Color(0xFF4CAF50);
    } else if (task.status == DownloadStatus.stopped &&
        task.taskStatus == 'complete') {
      label = l10n.completed;
      color = colorScheme.primaryContainer;
    } else {
      switch (task.status) {
        case DownloadStatus.active:
          label = l10n.downloading;
          color = colorScheme.primary;
        case DownloadStatus.waiting:
          label = l10n.waiting;
          color = colorScheme.secondary;
        case DownloadStatus.stopped:
          label = l10n.stopped;
          color = colorScheme.errorContainer;
      }
    }

    return (label: label, icon: statusIconFor(task), color: color);
  }

  static (String, Color) getStatusInfo(
    BuildContext context,
    DownloadTask task,
    ColorScheme colorScheme,
  ) {
    final visuals = getTaskVisuals(context, task, colorScheme);
    return (visuals.label, visuals.color);
  }

  static Icon getStatusIcon(DownloadTask task, Color color) {
    return Icon(statusIconFor(task), color: color);
  }

  static bool isPausedTask(DownloadTask task) {
    return task.status == DownloadStatus.waiting && task.taskStatus == 'paused';
  }

  static bool matchesActiveFilter(DownloadTask task) {
    return task.status == DownloadStatus.active || isPausedTask(task);
  }

  // Paused tasks intentionally appear in both "Downloading" and "Waiting"
  // filters to match the Motrix-style interaction model we chose.
  static bool matchesWaitingFilter(DownloadTask task) {
    return task.status == DownloadStatus.waiting;
  }

  static bool isSeedingTask(DownloadTask task) {
    return task.status == DownloadStatus.active &&
        task.bittorrentInfo != null &&
        task.bittorrentInfo!.isNotEmpty &&
        task.isSeeder;
  }

  static Future<void> pauseTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        final downloadDataService = Provider.of<DownloadDataService>(
          context,
          listen: false,
        );
        final client = downloadDataService.clientFor(targetInstance!);
        if (task.bittorrentInfo != null && task.bittorrentInfo!.isNotEmpty) {
          await client.forcePauseTask(task.id);
        } else {
          await client.pauseTask(task.id);
        }
        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.targetInstanceNotConnected)),
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted &&
          _handleIndeterminateResult(context, e, onTaskUpdated)) {
        return;
      }
      _logger.e(
        'Failed to pause task ${task.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToPauseTask('$e'))));
      }
    }
  }

  static Future<void> stopTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final deleteDownloadedFiles = shouldSkipDeleteConfirmation(context)
          ? false
          : await promptDeleteDownloadedFiles(context, [task]);
      if (deleteDownloadedFiles == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }

      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        final downloadDataService = Provider.of<DownloadDataService>(
          context,
          listen: false,
        );
        final client = downloadDataService.clientFor(targetInstance!);
        final result = await deleteTaskWithClient(
          client,
          task,
          deleteDownloadedFiles: deleteDownloadedFiles,
        );
        onTaskUpdated();
        _scheduleFollowUpRefresh(onTaskUpdated);
        if (result.hasFileDeletionErrors) {
          _logger.w(
            'Task ${task.id} removed with file cleanup warnings: ${result.fileDeletionErrors.join(', ')}',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.taskRemovedWithFileWarnings)),
            );
          }
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.targetInstanceNotConnected)),
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted &&
          _handleIndeterminateResult(context, e, onTaskUpdated)) {
        return;
      }
      _logger.e(
        'Failed to stop task ${task.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToRemoveTask('$e'))));
      }
    }
  }

  static Future<void> stopSeedingTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        final downloadDataService = Provider.of<DownloadDataService>(
          context,
          listen: false,
        );
        final client = downloadDataService.clientFor(targetInstance!);
        await client.changeOption(task.id, {'seed-time': '0'});
        onTaskUpdated();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.stoppingSeedingTip),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.targetInstanceNotConnected)),
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted &&
          _handleIndeterminateResult(context, e, onTaskUpdated)) {
        return;
      }
      _logger.e(
        'Failed to stop seeding task ${task.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToStopSeeding('$e'))));
      }
    }
  }

  static Future<void> resumeTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        final downloadDataService = Provider.of<DownloadDataService>(
          context,
          listen: false,
        );
        final client = downloadDataService.clientFor(targetInstance!);
        await client.unpauseTask(task.id);
        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.targetInstanceNotConnected)),
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted &&
          _handleIndeterminateResult(context, e, onTaskUpdated)) {
        return;
      }
      _logger.e(
        'Failed to resume task ${task.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToResumeTask('$e'))));
      }
    }
  }

  static Future<void> removeFailedTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final deleteDownloadedFiles = shouldSkipDeleteConfirmation(context)
          ? false
          : await promptDeleteDownloadedFiles(context, [task]);
      if (deleteDownloadedFiles == null) {
        return;
      }
      if (!context.mounted) {
        return;
      }

      final targetInstance = instanceManager.getInstanceById(task.instanceId);

      if (targetInstance?.status == ConnectionStatus.connected) {
        final downloadDataService = Provider.of<DownloadDataService>(
          context,
          listen: false,
        );
        final client = downloadDataService.clientFor(targetInstance!);
        final result = await deleteTaskWithClient(
          client,
          task,
          deleteDownloadedFiles: deleteDownloadedFiles,
        );
        onTaskUpdated();
        _scheduleFollowUpRefresh(onTaskUpdated);
        if (result.hasFileDeletionErrors) {
          _logger.w(
            'Failed task ${task.id} removed with file cleanup warnings: ${result.fileDeletionErrors.join(', ')}',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.taskRemovedWithFileWarnings)),
            );
          }
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.targetInstanceNotConnected)),
        );
      }
    } catch (e, stackTrace) {
      if (context.mounted &&
          _handleIndeterminateResult(context, e, onTaskUpdated)) {
        return;
      }
      _logger.e(
        'Failed to remove failed task ${task.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToRemoveFailedTask('$e'))),
        );
      }
    }
  }

  static Future<void> retryTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      if (buildTaskRetrySources(task).isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.retryTaskSourceUnavailable)),
          );
        }
        return;
      }

      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status != ConnectionStatus.connected) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.targetInstanceNotConnected)),
          );
        }
        return;
      }

      final downloadDataService = Provider.of<DownloadDataService>(
        context,
        listen: false,
      );
      final client = downloadDataService.clientFor(targetInstance!);
      await retryTaskWithClient(client, task);
      onTaskUpdated();
    } catch (e, stackTrace) {
      if (context.mounted &&
          _handleIndeterminateResult(context, e, onTaskUpdated)) {
        return;
      }
      _logger.e(
        'Failed to retry task ${task.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToRetryTask('$e'))));
      }
    }
  }

  static Future<List<String>> retryTaskWithClient(
    Aria2RpcClient client,
    DownloadTask task, {
    Future<Map<String, dynamic>> Function()? getOptionsOverride,
    Future<String> Function(List<String> uris, Map<String, dynamic> options)?
    addUriOverride,
    Future<String?> Function(String gid)? getTaskStatusOverride,
    Future<String> Function(String gid)? removeTaskOverride,
    Future<String> Function(String gid)? removeDownloadResultOverride,
    Future<bool> Function()? saveSessionOverride,
  }) async {
    final sources = buildTaskRetrySources(task);
    if (sources.isEmpty) {
      throw const RpcException('The original task source is unavailable');
    }

    final options = <String, dynamic>{};
    try {
      final currentOptions = getOptionsOverride != null
          ? await getOptionsOverride()
          : await client.getOption(task.id);
      for (final key in _portableRetryOptionKeys) {
        final value = currentOptions[key];
        if (value == null || value is String && value.trim().isEmpty) {
          continue;
        }
        if (value is List && value.isEmpty) {
          continue;
        }
        options[key] = value;
      }
    } catch (error, stackTrace) {
      _logger.w(
        'Failed to read options for retrying task ${task.id}; using fallback options',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final taskDir = task.dir?.trim() ?? '';
    if (taskDir.isNotEmpty) {
      options['dir'] = taskDir;
    }
    final isBitTorrent = sources.any(
      (source) => source.uris.any(
        (uri) => Uri.tryParse(uri)?.scheme.toLowerCase() == 'magnet',
      ),
    );
    if (isBitTorrent) {
      options.putIfAbsent('check-integrity', () => 'true');
      options.putIfAbsent('force-save', () => 'true');
    }

    final createdGids = <String>[];
    try {
      for (final source in sources) {
        final sourceOptions = Map<String, dynamic>.from(options);
        if (!isBitTorrent && source.outputName != null) {
          sourceOptions['out'] = source.outputName;
        }
        final gid = addUriOverride != null
            ? await addUriOverride(source.uris, sourceOptions)
            : await client.addUri(source.uris, sourceOptions);
        createdGids.add(gid);
      }
    } catch (error, stackTrace) {
      if (error is RpcResultIndeterminateException) {
        Error.throwWithStackTrace(error, stackTrace);
      }
      for (final gid in createdGids.reversed) {
        try {
          String? status;
          try {
            status = getTaskStatusOverride != null
                ? await getTaskStatusOverride(gid)
                : (await client.getTaskStatus(gid))['status']?.toString();
          } catch (statusError, statusStackTrace) {
            _logger.w(
              'Failed to inspect partially retried task $gid; using active-task rollback',
              error: statusError,
              stackTrace: statusStackTrace,
            );
          }
          final isStopped =
              status == 'complete' || status == 'error' || status == 'removed';
          if (isStopped) {
            if (removeDownloadResultOverride != null) {
              await removeDownloadResultOverride(gid);
            } else {
              await client.removeDownloadResult(gid);
            }
          } else if (removeTaskOverride != null) {
            await removeTaskOverride(gid);
          } else {
            await client.removeTask(gid);
          }
        } catch (rollbackError, rollbackStackTrace) {
          _logger.w(
            'Failed to roll back partially retried task $gid',
            error: rollbackError,
            stackTrace: rollbackStackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (task.status == DownloadStatus.stopped) {
      try {
        if (removeDownloadResultOverride != null) {
          await removeDownloadResultOverride(task.id);
        } else {
          await client.removeDownloadResult(task.id);
        }
      } catch (error, stackTrace) {
        _logger.w(
          'Retried task ${task.id}, but failed to remove original result record',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    try {
      if (saveSessionOverride != null) {
        await saveSessionOverride();
      } else {
        await client.saveSession();
      }
    } catch (error, stackTrace) {
      _logger.w(
        'Retried task ${task.id}, but failed to save the aria2 session',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return createdGids;
  }

  static void _scheduleFollowUpRefresh(VoidCallback onTaskUpdated) {
    Future<void>.delayed(const Duration(milliseconds: 600), onTaskUpdated);
  }

  static bool _handleIndeterminateResult(
    BuildContext context,
    Object error,
    VoidCallback onTaskUpdated,
  ) {
    if (error is! RpcResultIndeterminateException) {
      return false;
    }
    _logger.w(
      'Task action result could not be confirmed; refreshing before retry',
      error: error,
    );
    onTaskUpdated();
    _scheduleFollowUpRefresh(onTaskUpdated);
    if (context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.rpcOperationResultUnknown)));
    }
    return true;
  }

  static Future<List<String>> _deleteDownloadedFiles(DownloadTask task) async {
    final dir = task.dir;
    if (dir == null || dir.isEmpty) {
      return const [];
    }

    final baseDir = _normalizePath(dir);
    final targets = <String>{};

    if (task.files != null && task.files!.isNotEmpty) {
      for (final file in task.files!) {
        final path = file['path']?.toString() ?? '';
        if (path.isEmpty) {
          continue;
        }
        final normalizedPath = _normalizePath(path);
        targets.add(normalizedPath);
        targets.add(_normalizePath('$normalizedPath.aria2'));
      }
    } else {
      if (task.name.trim().isEmpty) {
        return const [
          'Skipped file deletion because task name is empty and no file list is available.',
        ];
      }
      final defaultTarget = _normalizePath(p.join(dir, task.name));
      targets.add(defaultTarget);
      targets.add(_normalizePath('$defaultTarget.aria2'));
    }

    final failedTargets = <String>[];
    final parentDirectories = <String>{};
    final sortedTargets = targets.toList()
      ..sort((left, right) => right.length.compareTo(left.length));

    for (final target in sortedTargets) {
      if (!_isWithinBaseDirectory(target, baseDir)) {
        failedTargets.add('Skipped path outside base directory: $target');
        continue;
      }

      try {
        final entityType = await FileSystemEntity.type(
          target,
          followLinks: false,
        );
        switch (entityType) {
          case FileSystemEntityType.file:
            await File(target).delete();
            parentDirectories.add(_normalizePath(File(target).parent.path));
            break;
          case FileSystemEntityType.link:
            await Link(target).delete();
            parentDirectories.add(_normalizePath(Link(target).parent.path));
            break;
          case FileSystemEntityType.directory:
            if (target == baseDir) {
              failedTargets.add(
                'Skipped recursive deletion of base directory: $target',
              );
              break;
            }
            await Directory(target).delete(recursive: true);
            parentDirectories.add(
              _normalizePath(Directory(target).parent.path),
            );
            break;
          case FileSystemEntityType.notFound:
            break;
          default:
            break;
        }
      } catch (error) {
        failedTargets.add('$target ($error)');
      }
    }

    for (final parent
        in parentDirectories.toList()
          ..sort((left, right) => right.length.compareTo(left.length))) {
      await _cleanupEmptyDirectories(parent, baseDir);
    }

    return failedTargets;
  }

  static Future<void> _cleanupEmptyDirectories(
    String startPath,
    String stopAtPath,
  ) async {
    var currentPath = _normalizePath(startPath);
    final stopPath = _normalizePath(stopAtPath);

    while (_isWithinBaseDirectory(currentPath, stopPath) &&
        currentPath != stopPath) {
      final directory = Directory(currentPath);
      final entityType = await FileSystemEntity.type(
        currentPath,
        followLinks: false,
      );
      if (entityType == FileSystemEntityType.link) {
        break;
      }
      if (!directory.existsSync()) {
        currentPath = _normalizePath(directory.parent.path);
        continue;
      }

      final children = directory.listSync();
      if (children.isNotEmpty) {
        break;
      }

      await directory.delete();
      currentPath = _normalizePath(directory.parent.path);
    }
  }

  static bool _isWithinBaseDirectory(String targetPath, String baseDirPath) {
    final normalizedTarget = _normalizePath(targetPath);
    final normalizedBase = _normalizePath(baseDirPath);
    return normalizedTarget == normalizedBase ||
        normalizedTarget.startsWith('$normalizedBase${Platform.pathSeparator}');
  }

  static String _normalizePath(String path) {
    var normalized = p.canonicalize(p.absolute(path));
    if (normalized.length > 1 && normalized.endsWith(Platform.pathSeparator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static bool isWithinBaseDirectoryForTesting(
    String targetPath,
    String baseDirPath,
  ) => _isWithinBaseDirectory(targetPath, baseDirPath);

  static Future<List<String>> deleteDownloadedFilesForTesting(
    DownloadTask task,
  ) => _deleteDownloadedFiles(task);
}
