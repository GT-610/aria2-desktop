import 'package:flutter/material.dart';
import '../models/download_task.dart';
import '../utils/task_utils.dart';

// Dialog for displaying detailed information about a download task
class TaskDetailsDialog extends StatelessWidget {
  final DownloadTask task;
  final Map<String, String> instanceNames;

  const TaskDetailsDialog({
    Key? key,
    required this.task,
    required this.instanceNames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Implementation will be added later
    return AlertDialog(
      title: Text(task.name),
      content: const SizedBox(),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  // Show dialog static method
  static void show(BuildContext context, DownloadTask task, Map<String, String> instanceNames) {
    showDialog(
      context: context,
      builder: (context) => TaskDetailsDialog(
        task: task,
        instanceNames: instanceNames,
      ),
    );
  }
}