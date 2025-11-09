// Flutter & third-party packages
import 'package:flutter/material.dart';

// Models
import '../models/download_task.dart';
import '../enums.dart';

// Services
import '../services/download_task_service.dart';

// Utilities
import '../../../utils/format_utils.dart';

// Task list item component for displaying individual download tasks
class TaskListItem extends StatelessWidget {
  final DownloadTask task;
  final Map<String, String> instanceNames;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final VoidCallback onTaskUpdated;
  final Function(DownloadTask) onOpenDirectory;

  const TaskListItem({
    super.key,
    required this.task,
    required this.instanceNames,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    required this.onTaskUpdated,
    required this.onOpenDirectory,
  });

  // Get instance name by ID
  String _getInstanceName(String instanceId) {
    return instanceNames[instanceId] ?? '未知实例';
  }





  // Handle task pause
  Future<void> _handlePauseTask(BuildContext context) async {
    await DownloadTaskService.pauseTask(context, task.id, onTaskUpdated);
  }

  // Handle task stop
  Future<void> _handleStopTask(BuildContext context) async {
    await DownloadTaskService.stopTask(context, task.id, onTaskUpdated);
  }

  // Handle task resume
  Future<void> _handleResumeTask(BuildContext context) async {
    await DownloadTaskService.resumeTask(context, task.id, onTaskUpdated);
  }

  // Handle task retry
  Future<void> _handleRetryTask(BuildContext context) async {
    await DownloadTaskService.retryTask(context, task, onTaskUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (statusText, statusColor) = DownloadTaskService.getStatusInfo(task, colorScheme);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Task name and status icon
              Row(
                children: [
                  DownloadTaskService.getStatusIcon(task, statusColor),
                  const SizedBox(width: 12),
                  // Progress percentage - styled like download speed
                  if (task.progress > 0)
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${(task.progress * 100).toInt()}%',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Text(
                      task.name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Download and upload speed display
                  if (task.status == DownloadStatus.active)
                    Row(
                      children: [
                        // Upload speed
                        Container(
                          margin: EdgeInsets.only(right: 8),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.upload, size: 12, color: colorScheme.secondary),
                              SizedBox(width: 4),
                              Text(
                                task.uploadSpeed,
                                style: TextStyle(
                                  color: colorScheme.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Download speed
                        Container(
                          margin: EdgeInsets.only(right: 8),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.download, size: 12, color: colorScheme.primary),
                              SizedBox(width: 4),
                              Text(
                                task.downloadSpeed,
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  // Status label
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
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
              
              const SizedBox(height: 12),
              
              // Progress bar (shown for all statuses with slight style variation for non-active)
              Stack(
                children: [
                  LinearProgressIndicator(
                    value: task.progress,
                    borderRadius: BorderRadius.circular(10),
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      // Use tertiary color for paused tasks
                      (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') 
                        ? colorScheme.tertiary 
                        : (task.status == DownloadStatus.active ? statusColor : statusColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Task details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // File size info and instance name
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Instance name
                      Container(
                        margin: EdgeInsets.only(bottom: 2),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getInstanceName(task.instanceId),
                          style: TextStyle(
                            color: colorScheme.tertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Size info with remaining time
                      Text(
                        '${task.completedSize} / ${task.size} (${calculateRemainingTime(task.progress, task.downloadSpeed)})',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  // Action buttons - Dynamic based on task status
                  Row(
                    children: [
                      if (task.status == DownloadStatus.active) ...[
                        // Pause button
                        Tooltip(
                          message: '暂停',
                          child: IconButton(
                            icon: const Icon(Icons.pause),
                            onPressed: () => _handlePauseTask(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ),
                        SizedBox(width: 8), // Add spacing between buttons
                        // Stop button
                        Tooltip(
                          message: '停止',
                          child: IconButton(
                            icon: const Icon(Icons.stop),
                            onPressed: () => _handleStopTask(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ),
                      ] else if (task.status == DownloadStatus.waiting) ...[
                        // Resume button
                        Tooltip(
                          message: '继续',
                          child: IconButton(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => _handleResumeTask(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ),
                        SizedBox(width: 8), // Add spacing between buttons
                        // Stop button
                        Tooltip(
                          message: '停止',
                          child: IconButton(
                            icon: const Icon(Icons.stop),
                            onPressed: () => _handleStopTask(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ),
                      ] else if (task.status == DownloadStatus.stopped && task.taskStatus != 'complete') ...[
                        // Retry button - Don't show for completed tasks
                        Tooltip(
                          message: '重试',
                          child: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _handleRetryTask(context),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ),
                      ],
                      SizedBox(width: 8), // Add spacing between buttons
                      // Open directory button - Show for all statuses
                      Tooltip(
                        message: '打开下载目录',
                        child: IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () => onOpenDirectory(task),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      )
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}