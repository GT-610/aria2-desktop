import 'package:flutter/material.dart';
import '../models/download_task.dart';
import '../utils/task_utils.dart';

// Task list item component for displaying individual download tasks
class TaskListItem extends StatelessWidget {
  final DownloadTask task;
  final Map<String, String> instanceNames;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const TaskListItem({
    Key? key,
    required this.task,
    required this.instanceNames,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Implementation will be added later
    return Container();
  }
}