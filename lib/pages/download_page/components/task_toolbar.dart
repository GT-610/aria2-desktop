import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

class TaskToolbar extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onPauseAll;
  final VoidCallback onResumeAll;
  final VoidCallback onDeleteAll;
  final VoidCallback onSearch;

  const TaskToolbar({
    super.key,
    required this.onAddTask,
    required this.onPauseAll,
    required this.onResumeAll,
    required this.onDeleteAll,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.surfaceContainerHighest),
        ),
      ),
      child: Row(
        children: [
          Btn.elevated(
            text: '添加任务',
            icon: const Icon(Icons.add),
            onTap: onAddTask,
          ),
          const SizedBox(width: 12),
          Btn.tile(
            text: '全部暂停',
            icon: const Icon(Icons.pause),
            onTap: onPauseAll,
          ),
          const SizedBox(width: 12),
          Btn.tile(
            text: '全部继续',
            icon: const Icon(Icons.play_arrow),
            onTap: onResumeAll,
          ),
          const SizedBox(width: 12),
          Btn.tile(
            text: '全部删除',
            icon: const Icon(Icons.delete),
            onTap: onDeleteAll,
          ),
          const Spacer(),
          Btn.icon(icon: const Icon(Icons.search), text: '搜索', onTap: onSearch),
        ],
      ),
    );
  }
}
