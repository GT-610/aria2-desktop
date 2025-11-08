// Flutter & third-party packages
import 'package:flutter/material.dart';

/// Task action toolbar component with add, pause, resume, and delete buttons
class TaskToolbar extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onPauseAll;
  final VoidCallback onResumeAll;
  final VoidCallback onDeleteAll;
  final VoidCallback onSearch;

  const TaskToolbar({
    Key? key,
    required this.onAddTask,
    required this.onPauseAll,
    required this.onResumeAll,
    required this.onDeleteAll,
    required this.onSearch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.surfaceContainerHighest)),
      ),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onAddTask,
            icon: const Icon(Icons.add),
            label: const Text('添加任务'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onPauseAll,
            icon: const Icon(Icons.pause),
            label: const Text('全部暂停'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onResumeAll,
            icon: const Icon(Icons.play_arrow),
            label: const Text('全部继续'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onDeleteAll,
            icon: const Icon(Icons.delete),
            label: const Text('全部删除'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Spacer(),
          IconButton.outlined(
            onPressed: onSearch,
            icon: const Icon(Icons.search),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}