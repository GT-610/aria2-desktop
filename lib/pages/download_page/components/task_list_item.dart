import 'package:flutter/material.dart';

import '../../../generated/l10n/l10n.dart';
import '../enums.dart';
import '../models/download_task.dart';
import '../services/download_task_service.dart';
import '../utils/task_utils.dart';

class TaskListItem extends StatelessWidget {
  final DownloadTask task;
  final Map<String, String> instanceNames;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool showSelectionControl;
  final bool showProgressBar;
  final VoidCallback onTaskUpdated;
  final Function(DownloadTask) onOpenDirectory;

  const TaskListItem({
    super.key,
    required this.task,
    required this.instanceNames,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.showSelectionControl = false,
    this.showProgressBar = true,
    required this.onTaskUpdated,
    required this.onOpenDirectory,
  });

  String _getInstanceName(BuildContext context, String instanceId) {
    return instanceNames[instanceId] ??
        AppLocalizations.of(context)!.unknownInstance;
  }

  Future<void> _handlePauseTask(BuildContext context) async {
    await DownloadTaskService.pauseTask(context, task, onTaskUpdated);
  }

  Future<void> _handleStopTask(BuildContext context) async {
    await DownloadTaskService.stopTask(context, task, onTaskUpdated);
  }

  Future<void> _handleResumeTask(BuildContext context) async {
    await DownloadTaskService.resumeTask(context, task, onTaskUpdated);
  }

  Future<void> _handleRemoveFailedTask(BuildContext context) async {
    await DownloadTaskService.removeFailedTask(context, task, onTaskUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (statusText, statusColor) = DownloadTaskService.getStatusInfo(
      context,
      task,
      colorScheme,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shadowColor: colorScheme.shadow,
      surfaceTintColor: colorScheme.surface,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 1.2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showSelectionControl) ...[
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                  ],
                  DownloadTaskService.getStatusIcon(task, statusColor),
                  const SizedBox(width: 12),
                  if (task.progress > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${(task.progress * 100).toInt()}%',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      task.name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.status == DownloadStatus.active)
                    Row(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.upload,
                                size: 14,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.uploadSpeed,
                                style: TextStyle(
                                  color: colorScheme.secondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.download,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.downloadSpeed,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (showProgressBar) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: task.progress,
                  borderRadius: BorderRadius.circular(12),
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    (task.status == DownloadStatus.waiting &&
                            task.taskStatus == 'paused')
                        ? colorScheme.tertiary
                        : (task.status == DownloadStatus.active
                              ? statusColor
                              : statusColor.withValues(alpha: 0.6)),
                  ),
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _getInstanceName(context, task.instanceId),
                            style: TextStyle(
                              color: colorScheme.tertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          task.status == DownloadStatus.active
                              ? '${task.completedSize} / ${task.size} (${TaskUtils.calculateRemainingTime(task)})'
                              : '${task.completedSize} / ${task.size}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.status == DownloadStatus.active) ...[
                        Tooltip(
                          message: l10n.pause,
                          child: IconButton(
                            icon: const Icon(Icons.pause),
                            onPressed: () => _handlePauseTask(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: l10n.stop,
                          child: IconButton(
                            icon: const Icon(Icons.stop),
                            onPressed: () => _handleStopTask(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ] else if (task.status == DownloadStatus.waiting) ...[
                        Tooltip(
                          message: l10n.resume,
                          child: IconButton(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => _handleResumeTask(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: l10n.stop,
                          child: IconButton(
                            icon: const Icon(Icons.stop),
                            onPressed: () => _handleStopTask(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ] else if (task.status == DownloadStatus.stopped &&
                          task.taskStatus != 'complete') ...[
                        Tooltip(
                          message: l10n.removeFailedTask,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _handleRemoveFailedTask(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Tooltip(
                        message: l10n.openDownloadDir,
                        child: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () => onOpenDirectory(task),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
