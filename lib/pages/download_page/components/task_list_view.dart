import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/download_task.dart';
import '../services/download_task_service.dart';
import 'task_list_item.dart';
import '../../../services/instance_manager.dart';

/// Component for displaying the list of download tasks with empty states handling
class TaskListView extends StatelessWidget {
  final List<DownloadTask> tasks;
  final Map<String, String> instanceNames;
  final Function(DownloadTask) onTaskTap;
  final Function(DownloadTask) onTaskLongPress;
  final Function(DownloadTask) onTaskSelectionToggle;
  final Set<String> selectedTaskKeys;
  final VoidCallback onTaskUpdated;

  const TaskListView({
    super.key,
    required this.tasks,
    required this.instanceNames,
    required this.onTaskTap,
    required this.onTaskLongPress,
    required this.onTaskSelectionToggle,
    required this.selectedTaskKeys,
    required this.onTaskUpdated,
  });

  String _taskKey(DownloadTask task) => '${task.instanceId}::${task.id}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final instanceManager = context.read<InstanceManager>();
    final connectedInstances = instanceManager.getConnectedInstances();
    final hasConnectedInstances = connectedInstances.isNotEmpty;

    if (!hasConnectedInstances) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No connected instances. Connect an instance to view tasks.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The download list combines tasks from the built-in instance and any connected remote instances.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No tasks', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add a task or switch filters to see downloads from connected instances.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];

        return TaskListItem(
          task: task,
          instanceNames: instanceNames,
          onTap: () {
            if (selectedTaskKeys.isNotEmpty) {
              onTaskSelectionToggle(task);
            } else {
              onTaskTap(task);
            }
          },
          onLongPress: () => onTaskLongPress(task),
          isSelected: selectedTaskKeys.contains(_taskKey(task)),
          showSelectionControl: selectedTaskKeys.isNotEmpty,
          onTaskUpdated: onTaskUpdated,
          onOpenDirectory: (task) async {
            final dir = task.dir;
            if (dir == null || dir.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No download directory available'),
                ),
              );
              return;
            }

            DownloadTaskService.openDirectory(task);
          },
        );
      },
    );
  }
}
