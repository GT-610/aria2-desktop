import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../services/aria2_rpc_client.dart';
import '../../../services/download_data_service.dart';
import '../../../services/instance_manager.dart';
import '../enums.dart';
import '../models/download_task.dart';
import '../services/download_task_service.dart';

void _logE(String message) {
  lprint('[TaskActionDialogs] $message');
}

enum TaskActionType { resume, pause, delete }

class TaskActionDialogs {
  static Future<void> showTaskActionDialog(
    BuildContext context,
    TaskActionType actionType, {
    VoidCallback? onActionCompleted,
    List<DownloadTask>? tasks,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final instanceManager = p.Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    final downloadDataService = p.Provider.of<DownloadDataService>(
      context,
      listen: false,
    );

    final String title;
    final String allInstancesText;
    final String instanceActionPrefix;
    final targetInstances = instanceManager.getConnectedInstances();

    switch (actionType) {
      case TaskActionType.resume:
        title = l10n.resumeTasks;
        allInstancesText = l10n.actionAcrossAllInstances(l10n.resumeTasks);
        instanceActionPrefix = l10n.resumeTasks;
        break;
      case TaskActionType.pause:
        title = l10n.pauseTasks;
        allInstancesText = l10n.actionAcrossAllInstances(l10n.pauseTasks);
        instanceActionPrefix = l10n.pauseTasks;
        break;
      case TaskActionType.delete:
        title = l10n.deleteTasks;
        allInstancesText = l10n.actionAcrossAllInstances(l10n.deleteTasks);
        instanceActionPrefix = l10n.deleteTasks;
        break;
    }

    final allTasks = tasks ?? downloadDataService.tasks;

    if (targetInstances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noConnectedInstancesForAction)),
      );
      return;
    }

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
              Text(
                l10n.chooseActionScope,
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              buildDialogOption(
                dialogContext,
                '$allInstancesText (${allTasks.length})',
                onTap: () async {
                  Navigator.pop(dialogContext);
                  bool deleteDownloadedFiles = false;
                  if (actionType == TaskActionType.delete) {
                    final choice =
                        await DownloadTaskService.promptDeleteDownloadedFiles(
                          context,
                          allTasks,
                        );
                    if (choice == null) {
                      return;
                    }
                    deleteDownloadedFiles = choice;
                  }
                  await _performActionForAllInstances(
                    actionType,
                    allTasks,
                    instanceManager,
                    deleteDownloadedFiles: deleteDownloadedFiles,
                  );
                  onActionCompleted?.call();
                },
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: colorScheme.surfaceContainerHighest),
              const SizedBox(height: 8),
              ...targetInstances.map((instance) {
                final instanceTasks = allTasks
                    .where((task) => task.instanceId == instance.id)
                    .toList();
                return Column(
                  children: [
                    buildDialogOption(
                      dialogContext,
                      '${l10n.actionInInstance(instanceActionPrefix, instance.name)} (${instanceTasks.length})',
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        bool deleteDownloadedFiles = false;
                        if (actionType == TaskActionType.delete) {
                          final choice =
                              await DownloadTaskService.promptDeleteDownloadedFiles(
                                context,
                                instanceTasks,
                              );
                          if (choice == null) {
                            return;
                          }
                          deleteDownloadedFiles = choice;
                        }
                        await _performActionForInstance(
                          instance,
                          actionType,
                          instanceTasks,
                          deleteDownloadedFiles: deleteDownloadedFiles,
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
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

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

  static Future<void> _performActionForAllInstances(
    TaskActionType actionType,
    List<DownloadTask> allTasks,
    InstanceManager instanceManager, {
    bool deleteDownloadedFiles = false,
  }) async {
    final connectedInstances = instanceManager.getConnectedInstances();

    for (final instance in connectedInstances) {
      final instanceTasks = allTasks
          .where((task) => task.instanceId == instance.id)
          .toList();
      await _performActionForInstance(
        instance,
        actionType,
        instanceTasks,
        deleteDownloadedFiles: deleteDownloadedFiles,
      );
    }
  }

  static Future<void> _performActionForInstance(
    Aria2Instance instance,
    TaskActionType actionType,
    List<DownloadTask> tasks, {
    bool deleteDownloadedFiles = false,
  }) async {
    if (tasks.isEmpty) {
      _logE('No tasks to process for instance: ${instance.name}');
      return;
    }

    Aria2RpcClient? client;
    var successCount = 0;
    var failCount = 0;

    try {
      client = Aria2RpcClient(instance);

      for (final task in tasks) {
        try {
          switch (actionType) {
            case TaskActionType.resume:
              if (task.status == DownloadStatus.waiting &&
                  task.taskStatus == 'paused') {
                await client.unpauseTask(task.id);
                successCount++;
              }
              break;
            case TaskActionType.pause:
              if ((task.status == DownloadStatus.active ||
                      task.status == DownloadStatus.waiting) &&
                  task.taskStatus != 'paused') {
                await client.pauseTask(task.id);
                successCount++;
              }
              break;
            case TaskActionType.delete:
              final result = await DownloadTaskService.deleteTaskWithClient(
                client,
                task,
                deleteDownloadedFiles: deleteDownloadedFiles,
              );
              if (result.hasFileDeletionErrors) {
                _logE(
                  'Task ${task.id} removed with file cleanup warnings: ${result.fileDeletionErrors.join(', ')}',
                );
              }
              successCount++;
              break;
          }
        } catch (e) {
          failCount++;
          _logE('Failed to ${actionType.name} task ${task.id}: $e');
        }
      }

      _logE(
        'Action ${actionType.name} completed for instance ${instance.name}: $successCount success, $failCount failed',
      );
    } catch (e) {
      _logE('Error executing task operation for instance ${instance.name}: $e');
    } finally {
      client?.close();
    }
  }
}
