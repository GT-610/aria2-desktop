// Flutter & third-party packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Components
import 'task_list_item.dart';

// Models
import '../models/download_task.dart';
import '../../../models/aria2_instance.dart';

// Services
import '../../../services/instance_manager.dart';

/// Component for displaying the list of download tasks with empty states handling
class TaskListView extends StatelessWidget {
  final List<DownloadTask> tasks;
  final Map<String, String> instanceNames;
  final Function(DownloadTask) onTaskTap;
  final VoidCallback onTaskUpdated;

  const TaskListView({
    super.key,
    required this.tasks,
    required this.instanceNames,
    required this.onTaskTap,
    required this.onTaskUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Check if there are any connected instances
    final instanceManager = context.read<InstanceManager>();
    final hasConnectedInstances = instanceManager.instances.any((instance) => 
      instance.status == ConnectionStatus.connected
    );
    
    // If no connected instances, show special prompt
    if (!hasConnectedInstances) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            SizedBox(height: 16),
            Text('没有正在连接的实例，快去连接实例吧', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }
    
    // If there are connected instances but no tasks, show 'no tasks' message
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            SizedBox(height: 16),
            Text('暂无任务', style: theme.textTheme.titleMedium),
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
          onTap: () => onTaskTap(task),
          onTaskUpdated: onTaskUpdated,
          onOpenDirectory: (task) async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('打开目录功能暂时不可用')),
          );
        },
        );
      },
    );
  }
}