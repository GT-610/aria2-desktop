import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as p;

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../models/settings.dart';
import '../../../services/aria2_rpc_client.dart';
import '../../../services/download_data_service.dart';
import '../../../services/instance_manager.dart';
import '../../../utils/logging.dart';
import '../enums.dart';
import '../models/download_task.dart';
import '../services/download_task_service.dart';

final _logger = taggedLogger('TaskActionDialogs');

enum TaskActionType { resume, pause, delete }

class _TaskActionOutcome {
  const _TaskActionOutcome({
    this.successCount = 0,
    this.failCount = 0,
    this.skippedCount = 0,
    this.fileDeletionWarningCount = 0,
  });

  final int successCount;
  final int failCount;
  final int skippedCount;
  final int fileDeletionWarningCount;

  _TaskActionOutcome operator +(_TaskActionOutcome other) {
    return _TaskActionOutcome(
      successCount: successCount + other.successCount,
      failCount: failCount + other.failCount,
      skippedCount: skippedCount + other.skippedCount,
      fileDeletionWarningCount:
          fileDeletionWarningCount + other.fileDeletionWarningCount,
    );
  }

  bool get hasAnyWork =>
      successCount > 0 || failCount > 0 || fileDeletionWarningCount > 0;
}

class TaskActionDialogs {
  static bool canPerformAction(DownloadTask task, TaskActionType actionType) {
    switch (actionType) {
      case TaskActionType.resume:
        return task.status == DownloadStatus.waiting &&
            task.taskStatus == 'paused';
      case TaskActionType.pause:
        return (task.status == DownloadStatus.active ||
                task.status == DownloadStatus.waiting) &&
            task.taskStatus != 'paused';
      case TaskActionType.delete:
        return true;
    }
  }

  static List<DownloadTask> actionableTasks(
    List<DownloadTask> tasks,
    TaskActionType actionType,
  ) {
    return tasks.where((task) => canPerformAction(task, actionType)).toList();
  }

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
    final settings = p.Provider.of<Settings>(context, listen: false);
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
    final actionableAllTasks = actionableTasks(allTasks, actionType);

    if (targetInstances.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noConnectedInstancesForAction)),
      );
      return;
    }

    if (actionableAllTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.taskActionNoMatchingTasks(_actionLabel(l10n, actionType)),
          ),
        ),
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
                '$allInstancesText (${actionableAllTasks.length})',
                enabled: actionableAllTasks.isNotEmpty,
                onTap: () async {
                  Navigator.pop(dialogContext);
                  bool deleteDownloadedFiles = false;
                  if (actionType == TaskActionType.delete) {
                    if (!settings.skipDeleteConfirm) {
                      final choice =
                          await DownloadTaskService.promptDeleteDownloadedFiles(
                            context,
                            actionableAllTasks,
                          );
                      if (choice == null) {
                        return;
                      }
                      deleteDownloadedFiles = choice;
                    }
                  }
                  await _performActionForAllInstances(
                    context,
                    actionType,
                    actionableAllTasks,
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
                final instanceTasks = actionableTasks(
                  allTasks
                      .where((task) => task.instanceId == instance.id)
                      .toList(),
                  actionType,
                );
                return Column(
                  children: [
                    buildDialogOption(
                      dialogContext,
                      '${l10n.actionInInstance(instanceActionPrefix, instance.name)} (${instanceTasks.length})',
                      enabled: instanceTasks.isNotEmpty,
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        bool deleteDownloadedFiles = false;
                        if (actionType == TaskActionType.delete) {
                          if (!settings.skipDeleteConfirm) {
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
                        }
                        final outcome = await _performActionForInstance(
                          context,
                          instance,
                          actionType,
                          instanceTasks,
                          deleteDownloadedFiles: deleteDownloadedFiles,
                        );
                        _showActionOutcome(context, actionType, outcome);
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
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: enabled
                ? null
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  static Future<void> _performActionForAllInstances(
    BuildContext context,
    TaskActionType actionType,
    List<DownloadTask> allTasks,
    InstanceManager instanceManager, {
    bool deleteDownloadedFiles = false,
  }) async {
    final connectedInstances = instanceManager.getConnectedInstances();
    var totalOutcome = const _TaskActionOutcome();

    for (final instance in connectedInstances) {
      final instanceTasks = allTasks
          .where((task) => task.instanceId == instance.id)
          .toList();
      totalOutcome += await _performActionForInstance(
        context,
        instance,
        actionType,
        instanceTasks,
        deleteDownloadedFiles: deleteDownloadedFiles,
      );
    }

    _showActionOutcome(context, actionType, totalOutcome);
  }

  static Future<_TaskActionOutcome> _performActionForInstance(
    BuildContext context,
    Aria2Instance instance,
    TaskActionType actionType,
    List<DownloadTask> tasks, {
    bool deleteDownloadedFiles = false,
  }) async {
    if (tasks.isEmpty) {
      _logger.w('No tasks to process for instance ${instance.name}');
      return const _TaskActionOutcome();
    }

    Aria2RpcClient? client;
    var successCount = 0;
    var failCount = 0;
    var skippedCount = 0;
    var fileDeletionWarningCount = 0;

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
              } else {
                skippedCount++;
              }
              break;
            case TaskActionType.pause:
              if ((task.status == DownloadStatus.active ||
                      task.status == DownloadStatus.waiting) &&
                  task.taskStatus != 'paused') {
                if (task.bittorrentInfo != null &&
                    task.bittorrentInfo!.isNotEmpty) {
                  await client.forcePauseTask(task.id);
                } else {
                  await client.pauseTask(task.id);
                }
                successCount++;
              } else {
                skippedCount++;
              }
              break;
            case TaskActionType.delete:
              final result = await DownloadTaskService.deleteTaskWithClient(
                client,
                task,
                deleteDownloadedFiles: deleteDownloadedFiles,
              );
              if (result.hasFileDeletionErrors) {
                fileDeletionWarningCount++;
                _logger.w(
                  'Task ${task.id} removed with file cleanup warnings: ${result.fileDeletionErrors.join(', ')}',
                );
              }
              successCount++;
              break;
          }
        } catch (e, stackTrace) {
          failCount++;
          _logger.e(
            'Failed to ${actionType.name} task ${task.id}',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }

      _logger.i(
        'Action ${actionType.name} completed for instance ${instance.name}: $successCount success, $failCount failed, $skippedCount skipped',
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to execute ${actionType.name} action for instance ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      failCount += tasks.length;
    } finally {
      client?.close();
    }

    return _TaskActionOutcome(
      successCount: successCount,
      failCount: failCount,
      skippedCount: skippedCount,
      fileDeletionWarningCount: fileDeletionWarningCount,
    );
  }

  static void _showActionOutcome(
    BuildContext context,
    TaskActionType actionType,
    _TaskActionOutcome outcome,
  ) {
    if (!context.mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final actionLabel = _actionLabel(l10n, actionType);

    String message;
    if (!outcome.hasAnyWork && outcome.skippedCount > 0) {
      message = l10n.taskActionNoMatchingTasks(actionLabel);
    } else if (outcome.failCount == 0 && outcome.skippedCount == 0) {
      message = l10n.taskActionSummarySuccess(
        actionLabel,
        outcome.successCount,
      );
    } else {
      message = l10n.taskActionSummaryDetailed(
        actionLabel,
        outcome.successCount,
        outcome.failCount,
        outcome.skippedCount,
      );
    }

    if (outcome.fileDeletionWarningCount > 0) {
      message =
          '$message ${l10n.fileDeletionWarningsSummary(outcome.fileDeletionWarningCount)}';
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _actionLabel(AppLocalizations l10n, TaskActionType actionType) {
    switch (actionType) {
      case TaskActionType.resume:
        return l10n.resumeTasks;
      case TaskActionType.pause:
        return l10n.pauseTasks;
      case TaskActionType.delete:
        return l10n.deleteTasks;
    }
  }
}
