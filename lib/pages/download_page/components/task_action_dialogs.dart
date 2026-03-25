import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/logging.dart';
import '../../../services/instance_manager.dart';
import '../../../services/aria2_rpc_client.dart';
import '../../../services/download_data_service.dart';
import '../../../models/aria2_instance.dart';
import '../models/download_task.dart';
import '../enums.dart';

/// Task operation type enumeration
enum TaskActionType {
  resume,
  pause,
  delete
}

/// Task operation dialog component class
class TaskActionDialogs {
  static final AppLogger _logger = AppLogger('TaskActionDialogs');

  /// Show task operation dialog
  static Future<void> showTaskActionDialog(
    BuildContext context,
    TaskActionType actionType, {
    VoidCallback? onActionCompleted,
    List<DownloadTask>? tasks,
  }) async {
    final instanceManager = Provider.of<InstanceManager>(context, listen: false);
    final downloadDataService = Provider.of<DownloadDataService>(context, listen: false);

    final String title;
    final String allInstancesText;
    final String instanceActionText;
    final List<Aria2Instance> targetInstances;

    switch (actionType) {
      case TaskActionType.resume:
        title = '继续任务';
        allInstancesText = '继续所有实例的任务';
        instanceActionText = '继续实例 "';
        targetInstances = instanceManager.getConnectedInstances();
        break;
      case TaskActionType.pause:
        title = '暂停任务';
        allInstancesText = '暂停所有实例的任务';
        instanceActionText = '暂停实例 "';
        targetInstances = instanceManager.getConnectedInstances();
        break;
      case TaskActionType.delete:
        title = '删除任务';
        allInstancesText = '删除所有实例的任务';
        instanceActionText = '删除实例 "';
        targetInstances = instanceManager.getConnectedInstances();
        break;
    }

    final allTasks = tasks ?? downloadDataService.tasks;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildDialogOption(
                dialogContext,
                allInstancesText,
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _performActionForAllInstances(
                    actionType,
                    allTasks,
                    instanceManager,
                  );
                  onActionCompleted?.call();
                },
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: colorScheme.surfaceContainerHighest),
              const SizedBox(height: 8),
              ...targetInstances.map((instance) {
                final instanceTasks =
                    allTasks.where((t) => t.instanceId == instance.id).toList();
                return Column(
                  children: [
                    buildDialogOption(
                      dialogContext,
                      '$instanceActionText${instance.name}" 的任务 (${instanceTasks.length})',
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await _performActionForInstance(
                          instance,
                          actionType,
                          instanceTasks,
                        );
                        onActionCompleted?.call();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// Build dialog option
  static Widget buildDialogOption(
    BuildContext context,
    String text, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }

  /// Perform action for all instances
  static Future<void> _performActionForAllInstances(
    TaskActionType actionType,
    List<DownloadTask> allTasks,
    InstanceManager instanceManager,
  ) async {
    final connectedInstances = instanceManager.getConnectedInstances();

    for (final instance in connectedInstances) {
      final instanceTasks =
          allTasks.where((t) => t.instanceId == instance.id).toList();
      await _performActionForInstance(instance, actionType, instanceTasks);
    }
  }

  /// Perform action for single instance
  static Future<void> _performActionForInstance(
    Aria2Instance instance,
    TaskActionType actionType,
    List<DownloadTask> tasks,
  ) async {
    if (tasks.isEmpty) {
      _logger.d('No tasks to process for instance: ${instance.name}');
      return;
    }

    try {
      final client = Aria2RpcClient(instance);
      int successCount = 0;
      int failCount = 0;

      for (final task in tasks) {
        try {
          switch (actionType) {
            case TaskActionType.resume:
              if (task.status == DownloadStatus.waiting) {
                await client.unpauseTask(task.id);
                successCount++;
              }
              break;
            case TaskActionType.pause:
              if (task.status == DownloadStatus.active ||
                  task.status == DownloadStatus.waiting) {
                await client.pauseTask(task.id);
                successCount++;
              }
              break;
            case TaskActionType.delete:
              if (task.status == DownloadStatus.stopped) {
                await client.removeDownloadResult(task.id);
              } else {
                await client.removeTask(task.id);
              }
              successCount++;
              break;
          }
        } catch (e) {
          failCount++;
          _logger.w('Failed to ${actionType.name} task ${task.id}: $e');
        }
      }

      client.close();
      _logger.i(
          'Action ${actionType.name} completed for instance ${instance.name}: $successCount success, $failCount failed');
    } catch (e) {
      _logger.e('Error executing task operation for instance ${instance.name}',
          error: e);
    }
  }
}