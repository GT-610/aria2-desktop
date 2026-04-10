import 'dart:io';

import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/aria2_instance.dart';
import '../../../services/aria2_rpc_client.dart';
import '../../../services/instance_manager.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/logging.dart';
import '../enums.dart';
import '../models/download_task.dart';

void _logE(String msg) => fl.lprint('[DownloadTaskService] $msg');

class DownloadTaskService with Loggable {
  static final DownloadTaskService _instance = DownloadTaskService._();
  DownloadTaskService._();
  static DownloadTaskService get instance => _instance;

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
    );
  }

  static (String, Color) getStatusInfo(
    DownloadTask task,
    ColorScheme colorScheme,
  ) {
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return ('Paused', colorScheme.tertiary);
    }

    if (task.status == DownloadStatus.stopped &&
        task.taskStatus == 'complete') {
      return ('Completed', colorScheme.primaryContainer);
    }

    switch (task.status) {
      case DownloadStatus.active:
        return ('Downloading', colorScheme.primary);
      case DownloadStatus.waiting:
        return ('Waiting', colorScheme.secondary);
      case DownloadStatus.stopped:
        return ('Stopped', colorScheme.errorContainer);
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
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        final client = Aria2RpcClient(targetInstance!);
        await client.pauseTask(task.id);
        client.close();
        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The target instance is not connected.'),
          ),
        );
      }
    } catch (e) {
      _logE('Error pausing task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pause the task: $e')));
      }
    }
  }

  static Future<void> stopTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        final client = Aria2RpcClient(targetInstance!);
        if (task.status == DownloadStatus.stopped) {
          await client.removeDownloadResult(task.id);
        } else {
          await client.removeTask(task.id);
        }
        client.close();
        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The target instance is not connected.'),
          ),
        );
      }
    } catch (e) {
      _logE('Error stopping task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove the task: $e')),
        );
      }
    }
  }

  static Future<void> resumeTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);
      if (targetInstance?.status == ConnectionStatus.connected) {
        final client = Aria2RpcClient(targetInstance!);
        await client.unpauseTask(task.id);
        client.close();
        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The target instance is not connected.'),
          ),
        );
      }
    } catch (e) {
      _logE('Error resuming task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resume the task: $e')),
        );
      }
    }
  }

  static Future<void> removeFailedTask(
    BuildContext context,
    DownloadTask task,
    VoidCallback onTaskUpdated,
  ) async {
    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final targetInstance = instanceManager.getInstanceById(task.instanceId);

      if (targetInstance?.status == ConnectionStatus.connected) {
        final client = Aria2RpcClient(targetInstance!);
        if (task.status == DownloadStatus.stopped) {
          await client.removeDownloadResult(task.id);
        } else {
          await client.removeTask(task.id);
        }

        client.close();
        onTaskUpdated();
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The target instance is not connected.'),
          ),
        );
      }
    } catch (e) {
      _logE('Error removing failed task: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove the failed task: $e')),
        );
      }
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
