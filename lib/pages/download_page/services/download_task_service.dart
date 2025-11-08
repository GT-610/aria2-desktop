// Dart core imports
import 'dart:io';

// Third-party packages
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Models
import '../models/download_task.dart';
import '../enums.dart';
import '../../../models/aria2_instance.dart';

// Services
import '../../../services/aria2_rpc_client.dart';
import '../../../services/instance_manager.dart';

// Utilities
import '../../../utils/format_utils.dart';

/// Service to handle download task operations and data processing
class DownloadTaskService {
  /// Parse download task from Aria2 RPC response
  static DownloadTask parseTask(Map<String, dynamic> taskData, String instanceId) {
    String gid = taskData['gid'] ?? '';
    String status = taskData['status'] ?? '';
    String taskStatus = taskData['bittorrent']?['info']?['name'] != null
        ? 'complete'
        : 'active';
    
    // Determine download status
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

    // Get download and upload speeds
    String downloadSpeed = _formatSpeed(taskData['downloadSpeed'] ?? 0);
    String uploadSpeed = _formatSpeed(taskData['uploadSpeed'] ?? 0);

    // Calculate progress
    double progress = 0.0;
    int totalLength = taskData['totalLength'] != null && taskData['totalLength'] != ''
        ? int.tryParse(taskData['totalLength']) ?? 0
        : 0;
    int completedLength = taskData['completedLength'] != null && taskData['completedLength'] != ''
        ? int.tryParse(taskData['completedLength']) ?? 0
        : 0;

    if (totalLength > 0) {
      progress = completedLength / totalLength;
    }

    // Get file size info
    String size = formatBytes(totalLength);
    String completedSize = formatBytes(completedLength);

    // Get file name
    String name = '';
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

    // Get download directory
    String dir = taskData['dir'] ?? '';

    return DownloadTask(
      id: gid,
      name: name,
      status: downloadStatus,
      taskStatus: taskStatus,
      progress: progress,
      size: size,
      completedSize: completedSize,
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      dir: dir,
      instanceId: instanceId,
      isLocal: false, // Default value
      totalLengthBytes: totalLength,
      completedLengthBytes: completedLength,
      downloadSpeedBytes: taskData['downloadSpeed'] ?? 0,
      uploadSpeedBytes: taskData['uploadSpeed'] ?? 0,
    );
  }

  /// Get status text and color for a task
  static (String, Color) getStatusInfo(DownloadTask task, ColorScheme colorScheme) {
    // Check if task is paused
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return ('已暂停', colorScheme.tertiary);
    }
    
    // Special handling for completed tasks
    if (task.status == DownloadStatus.stopped && task.taskStatus == 'complete') {
      return ('已完成', colorScheme.primaryContainer);
    }
    
    switch (task.status) {
      case DownloadStatus.active:
        return ('下载中', colorScheme.primary);
      case DownloadStatus.waiting:
        return ('等待中', colorScheme.secondary);
      case DownloadStatus.stopped:
        return ('已停止', colorScheme.errorContainer);
    }
  }

  /// Get status icon for a task
  static Icon getStatusIcon(DownloadTask task, Color color) {
    // Check if task is paused
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return Icon(Icons.pause, color: color);
    }
    
    // Special handling for completed tasks
    if (task.status == DownloadStatus.stopped && task.taskStatus == 'complete') {
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

  /// Pause a download task
  static Future<void> pauseTask(BuildContext context, String taskId, VoidCallback onTaskUpdated) async {
    try {
      // Get instance manager and active instance
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      final activeInstance = instanceManager.activeInstance;
      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
        final client = Aria2RpcClient(activeInstance);
        await client.pauseTask(taskId);
        client.close();
        onTaskUpdated();
      }
    } catch (e) {
        if (kDebugMode) {
          print('Error pausing task: $e');
        }
      }
  }

  /// Stop a download task
  static Future<void> stopTask(BuildContext context, String taskId, VoidCallback onTaskUpdated) async {
    try {
      // Get instance manager and active instance
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      final activeInstance = instanceManager.activeInstance;
      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
        final client = Aria2RpcClient(activeInstance);
        await client.removeTask(taskId);
        client.close();
        onTaskUpdated();
      }
    } catch (e) {
        if (kDebugMode) {
          print('Error stopping task: $e');
        }
      }
  }

  /// Resume a paused download task
  static Future<void> resumeTask(BuildContext context, String taskId, VoidCallback onTaskUpdated) async {
    try {
      // Get instance manager and active instance
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      final activeInstance = instanceManager.activeInstance;
      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
        final client = Aria2RpcClient(activeInstance);
        await client.unpauseTask(taskId);
        client.close();
        onTaskUpdated();
      }
    } catch (e) {
        if (kDebugMode) {
          print('Error resuming task: $e');
        }
      }
  }

  /// Retry a failed download task
  static Future<void> retryTask(BuildContext context, DownloadTask task, VoidCallback onTaskUpdated) async {
    try {
      // Get instance manager and active instance
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      final activeInstance = instanceManager.activeInstance;
      
      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
        final client = Aria2RpcClient(activeInstance);
        
        // First remove the failed task
        await client.removeTask(task.id);
        
        // Then add it again (simplified retry mechanism)
        // In a real implementation, you might want to store and reuse the original URIs/magnet links
        // For now, this is a placeholder implementation
        if (kDebugMode) {
            print('Retrying task: ${task.id}');
          }
        
        client.close();
        onTaskUpdated();
      }
    } catch (e) {
        if (kDebugMode) {
          print('Error retrying task: $e');
        }
      }
  }

  /// Open the download directory of a task
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

  /// Filter tasks based on selected status filter
  static List<DownloadTask> filterTasks(List<DownloadTask> tasks, String filter) {
    switch (filter) {
      case 'all':
        return tasks;
      case 'active':
        return tasks.where((task) => task.status == DownloadStatus.active).toList();
      case 'waiting':
        return tasks.where((task) => task.status == DownloadStatus.waiting).toList();
      case 'stopped':
        return tasks.where((task) => task.status == DownloadStatus.stopped).toList();
      default:
        return tasks;
    }
  }
  
  /// Format speed value to human readable format
  static String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    
    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s', 'TB/s'];
    int i = 0;
    double value = bytesPerSecond.toDouble();
    
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    
    return '${value.toStringAsFixed(2)} ${suffixes[i]}';
  }
}