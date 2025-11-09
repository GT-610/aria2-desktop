import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/logging.dart';
import '../../../services/instance_manager.dart';
import '../../../models/aria2_instance.dart';

/// Task operation type enumeration
enum TaskActionType {
  resume,
  pause,
  delete
}

/// Task operation dialog component class
class TaskActionDialogs {
  static final AppLogger _logger = AppLogger('TaskActionDialogs');
  
  /// Show task operation dialog
  static Future<void> showTaskActionDialog(
    BuildContext context,
    TaskActionType actionType,
    {VoidCallback? onActionCompleted}
  ) async {
    // Get instance manager
    final instanceManager = Provider.of<InstanceManager>(context, listen: false);
    
    // Set title and button text based on action type
    final String title;
    final String allInstancesText;
    final String instanceActionText;
    final List<Aria2Instance> targetInstances;
    
    switch(actionType) {
      case TaskActionType.resume:
        title = '继续任务';
        allInstancesText = '继续所有实例的任务';
        instanceActionText = '继续实例 "';
        targetInstances = instanceManager.instances
            .where((instance) => instance.status == ConnectionStatus.connected)
            .toList();
        break;
      case TaskActionType.pause:
        title = '暂停任务';
        allInstancesText = '暂停所有实例的任务';
        instanceActionText = '暂停实例 "';
        targetInstances = instanceManager.instances
            .where((instance) => instance.status == ConnectionStatus.connected)
            .toList();
        break;
      case TaskActionType.delete:
        title = '删除任务';
        allInstancesText = '删除所有实例的任务';
        instanceActionText = '删除实例 "';
        targetInstances = instanceManager.instances
            .where((instance) => instance.status == ConnectionStatus.connected)
            .toList();
        break;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Operate tasks for all instances
              buildDialogOption(
                context,
                allInstancesText,
                onTap: () async {
                  Navigator.pop(context);
                  await _performActionForAllInstances(context, actionType);
                  onActionCompleted?.call();
                },
              ),
              const SizedBox(height: 8),
              // Separator line
              Container(height: 1, color: colorScheme.surfaceContainerHighest),
              const SizedBox(height: 8),
              // Target instances list
              ...targetInstances.map((instance) => Column(
                children: [
                  buildDialogOption(
                    context,
                    '$instanceActionText${instance.name}" 的任务',
                    onTap: () async {
                      Navigator.pop(context);
                      await _performActionForInstance(instance, actionType);
                      onActionCompleted?.call();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  /// Build dialog option
  static Widget buildDialogOption(
    BuildContext context,
    String text,
    {required VoidCallback onTap}
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  /// Perform action for all instances
  static Future<void> _performActionForAllInstances(
    BuildContext context,
    TaskActionType actionType,
  ) async {
    final instanceManager = Provider.of<InstanceManager>(context, listen: false);
    final connectedInstances = instanceManager.instances
        .where((instance) => instance.status == ConnectionStatus.connected)
        .toList();

    for (final instance in connectedInstances) {
      await _performActionForInstance(instance, actionType);
    }
  }

  /// Perform action for single instance
  static Future<void> _performActionForInstance(
    Aria2Instance instance,
    TaskActionType actionType,
  ) async {
    try {
      // Simplified implementation, actual operations commented out temporarily
      // In actual application, adjust these method calls according to Aria2RpcClient's actual API
      _logger.d('对实例 ${instance.name} 执行操作: $actionType');
      
      // Should implement corresponding functionality based on Aria2RpcClient's actual API here
      // final client = Aria2RpcClient(instance);
      // Call corresponding method based on actual API
      // client.close();
    } catch (e) {
      // Can add error handling here, such as showing error messages
      _logger.e('Error executing task operation', error: e);
    }
  }
}