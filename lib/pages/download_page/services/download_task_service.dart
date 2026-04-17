import 'dart:io';

import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../models/settings.dart';
import '../../../services/aria2_rpc_client.dart';
import '../../../services/instance_manager.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/logging.dart';
import '../enums.dart';
import '../models/download_task.dart';

void _logE(String msg) => fl.lprint('[DownloadTaskService] $msg');
void _logW(String msg) => fl.lprint('[DownloadTaskService][WARN] $msg');

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
  static final DownloadTaskService _instance = DownloadTaskService._();
  DownloadTaskService._();
  static DownloadTaskService get instance => _instance;

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
      _logW(
        'Task ${task.id} was removed from Aria2, but file cleanup had issues: ${fileDeletionErrors.join(', ')}',
      );
    }

    return DeleteTaskResult(
      removedFromAria2: true,
      fileDeletionErrors: fileDeletionErrors,
    );
  }

  static DownloadTask parseTask(
    Map<String, dynamic> taskData,
    String instanceId,
  ) {
    final gid = taskData['gid'] ?? '';
    final status = taskData['status'] ?? '';
    var taskStatus = taskData['bittorrent']?['info']?['name'] != null
        ? 'complete'
        : 'active';

    DownloadStatus downloadStatus;
    switch (status) {
      case 'active':
        downloadStatus = DownloadStatus.active;
        break;
      case 'waiting':
        downloadStatus = DownloadStatus.waiting;
        break;
      case 'paused':
        downloadStatus = DownloadStatus.waiting;
        taskStatus = 'paused';
        break;
      case 'complete':
        downloadStatus = DownloadStatus.stopped;
        taskStatus = 'complete';
        break;
      case 'error':
        downloadStatus = DownloadStatus.stopped;
        taskStatus = 'error';
        break;
      case 'removed':
        downloadStatus = DownloadStatus.stopped;
        taskStatus = 'removed';
        break;
      default:
        downloadStatus = DownloadStatus.waiting;
    }

    final totalLength =
        taskData['totalLength'] != null && taskData['totalLength'] != ''
        ? int.tryParse(taskData['totalLength']) ?? 0
        : 0;
    final completedLength =
        taskData['completedLength'] != null && taskData['completedLength'] != ''
        ? int.tryParse(taskData['completedLength']) ?? 0
        : 0;
    final progress = totalLength > 0 ? completedLength / totalLength : 0.0;

    var name = '';
    if (taskData['bittorrent']?['info']?['name'] != null) {
      name = taskData['bittorrent']['info']['name'];
    } else if (taskData['files'] is List && taskData['files'].isNotEmpty) {
      final path = taskData['files'][0]['path'] ?? '';
      if (path.contains('/')) {
        name = path.split('/').last;
      } else if (path.contains('\\')) {
        name = path.split('\\').last;
      } else {
        name = path;
      }
    }

    final dir = taskData['dir'] ?? '';
    final infoHash = taskData['infoHash']?.toString();
    final pieceLength = int.tryParse(taskData['pieceLength']?.toString() ?? '');
    final numPieces = int.tryParse(taskData['numPieces']?.toString() ?? '');

    return DownloadTask(
      id: gid,
      name: name,
      status: downloadStatus,
      taskStatus: taskStatus,
      progress: progress,
      size: formatBytes(totalLength),
      completedSize: formatBytes(completedLength),
      downloadSpeed: _formatSpeed(taskData['downloadSpeed'] ?? 0),
      uploadSpeed: _formatSpeed(taskData['uploadSpeed'] ?? 0),
      dir: dir,
      instanceId: instanceId,
      isLocal: false,
      totalLengthBytes: totalLength,
      completedLengthBytes: completedLength,
      downloadSpeedBytes: taskData['downloadSpeed'] ?? 0,
      uploadSpeedBytes: taskData['uploadSpeed'] ?? 0,
      infoHash: infoHash,
      pieceLength: pieceLength,
      numPieces: numPieces,
    );
  }

  static (String, Color) getStatusInfo(
    BuildContext context,
    DownloadTask task,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return (l10n.paused, colorScheme.tertiary);
    }

    if (task.status == DownloadStatus.stopped &&
        task.taskStatus == 'complete') {
      return (l10n.completed, colorScheme.primaryContainer);
    }

    switch (task.status) {
      case DownloadStatus.active:
        return (l10n.downloading, colorScheme.primary);
      case DownloadStatus.waiting:
        return (l10n.waiting, colorScheme.secondary);
      case DownloadStatus.stopped:
        return (l10n.stopped, colorScheme.errorContainer);
    }
  }

  static Icon getStatusIcon(DownloadTask task, Color color) {
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return Icon(Icons.pause, color: color);
    }

    if (task.status == DownloadStatus.stopped &&
        task.taskStatus == 'complete') {
      return Icon(Icons.check_circle, color: color);
    }

    switch (task.status) {
      case DownloadStatus.active:
        return Icon(Icons.file_download, color: color);
      case DownloadStatus.waiting:
        return Icon(Icons.schedule, color: color);
      case DownloadStatus.stopped:
        return Icon(Icons.pause_circle, color: color);
    }
  }

  static Future<void> pauseTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    Aria2RpcClient? client;
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        client = Aria2RpcClient(targetInstance!);
        await client.pauseTask(task.id);
        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.targetInstanceNotConnected)),
        );
      }
    } catch (e) {
      _logE('Error pausing task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToPauseTask('$e'))));
      }
    } finally {
      client?.close();
    }
  }

  static Future<void> stopTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    Aria2RpcClient? client;
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

      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        client = Aria2RpcClient(targetInstance!);
        final result = await deleteTaskWithClient(
          client,
          task,
          deleteDownloadedFiles: deleteDownloadedFiles,
        );
        if (result.hasFileDeletionErrors) {
          _logW(
            'Task ${task.id} removed with file cleanup warnings: ${result.fileDeletionErrors.join(', ')}',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.taskRemovedWithFileWarnings)),
            );
          }
        }
        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.targetInstanceNotConnected)),
        );
      }
    } catch (e) {
      _logE('Error stopping task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToRemoveTask('$e'))));
      }
    } finally {
      client?.close();
    }
  }

  static Future<void> resumeTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    Aria2RpcClient? client;
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        client = Aria2RpcClient(targetInstance!);
        await client.unpauseTask(task.id);
        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.targetInstanceNotConnected)),
        );
      }
    } catch (e) {
      _logE('Error resuming task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToResumeTask('$e'))));
      }
    } finally {
      client?.close();
    }
  }

  static Future<void> removeFailedTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    Aria2RpcClient? client;
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

      final targetInstance = instanceManager.getInstanceById(task.instanceId);

      if (targetInstance?.status == ConnectionStatus.connected) {
        client = Aria2RpcClient(targetInstance!);
        final result = await deleteTaskWithClient(
          client,
          task,
          deleteDownloadedFiles: deleteDownloadedFiles,
        );
        if (result.hasFileDeletionErrors) {
          _logW(
            'Failed task ${task.id} removed with file cleanup warnings: ${result.fileDeletionErrors.join(', ')}',
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.taskRemovedWithFileWarnings)),
            );
          }
        }

        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.targetInstanceNotConnected)),
        );
      }
    } catch (e) {
      _logE('Error removing failed task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToRemoveFailedTask('$e'))),
        );
      }
    } finally {
      client?.close();
    }
  }

  static Future<void> retryTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    Aria2RpcClient? client;
    try {
      final sourceUris = (task.uris ?? const <String>[])
          .map((uri) => uri.trim())
          .where((uri) => uri.isNotEmpty)
          .toList();
      if (sourceUris.isEmpty) {
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

      client = Aria2RpcClient(targetInstance!);
      final options = <String, dynamic>{};
      final taskDir = task.dir?.trim() ?? '';
      if (taskDir.isNotEmpty) {
        options['dir'] = taskDir;
      }
      final taskName = task.name.trim();
      if (taskName.isNotEmpty) {
        options['out'] = taskName;
      }

      await client.addUri(sourceUris, options);
      onTaskUpdated();
    } catch (e) {
      _logE('Error retrying task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedToRetryTask('$e'))));
      }
    } finally {
      client?.close();
    }
  }

  static void openDirectory(DownloadTask task) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      if (task.dir != null) {
        final directory = Directory(task.dir!);
        if (directory.existsSync()) {
          Process.start(
            Platform.isWindows
                ? 'explorer.exe'
                : Platform.isLinux
                ? 'xdg-open'
                : 'open',
            [task.dir!],
          );
        }
      }
    }
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
        final entityType = await FileSystemEntity.type(target);
        switch (entityType) {
          case FileSystemEntityType.file:
          case FileSystemEntityType.link:
            await File(target).delete();
            parentDirectories.add(_normalizePath(File(target).parent.path));
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

  static List<DownloadTask> filterTasks(
    List<DownloadTask> tasks,
    String filter,
  ) {
    switch (filter) {
      case 'all':
        return tasks;
      case 'active':
        return tasks
            .where((task) => task.status == DownloadStatus.active)
            .toList();
      case 'waiting':
        return tasks
            .where((task) => task.status == DownloadStatus.waiting)
            .toList();
      case 'stopped':
        return tasks
            .where((task) => task.status == DownloadStatus.stopped)
            .toList();
      default:
        return tasks;
    }
  }

  static String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';

    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s', 'TB/s'];
    var i = 0;
    var value = bytesPerSecond.toDouble();

    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }

    return '${value.toStringAsFixed(2)} ${suffixes[i]}';
  }
}
