import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../services/instance_manager.dart';
import '../models/download_task.dart';
import '../utils/task_utils.dart';
import 'task_list_item.dart';

/// Component for displaying the list of download tasks with empty states handling
class TaskListView extends StatelessWidget {
  final List<DownloadTask> tasks;
  final Map<String, String> instanceNames;
  final Function(DownloadTask) onTaskTap;
  final Function(DownloadTask) onTaskLongPress;
  final Function(DownloadTask) onTaskSelectionToggle;
  final Set<String> selectedTaskKeys;
  final VoidCallback onTaskUpdated;
  final bool hasActiveViewFilters;
  final VoidCallback? onClearViewFilters;

  const TaskListView({
    super.key,
    required this.tasks,
    required this.instanceNames,
    required this.onTaskTap,
    required this.onTaskLongPress,
    required this.onTaskSelectionToggle,
    required this.selectedTaskKeys,
    required this.onTaskUpdated,
    required this.hasActiveViewFilters,
    this.onClearViewFilters,
  });

  String _taskKey(DownloadTask task) => '${task.instanceId}::${task.id}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              l10n.noConnectedInstancesTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.combinedTaskListHint,
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
              hasActiveViewFilters
                  ? Icons.search_off_outlined
                  : Icons.inbox_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.noTasksTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.noTasksHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasActiveViewFilters && onClearViewFilters != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onClearViewFilters,
                child: Text(l10n.clear),
              ),
            ],
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
            await TaskUtils.openDownloadDirectory(context, task);
          },
        );
      },
    );
  }
}
