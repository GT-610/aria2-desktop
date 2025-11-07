import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/instance_manager.dart';
import '../../../models/aria2_instance.dart';

/// 任务操作类型枚举
enum TaskActionType {
  resume,
  pause,
  delete
}

/// 任务操作对话框组件类
class TaskActionDialogs {
  /// 显示任务操作对话框
  static Future<void> showTaskActionDialog(
    BuildContext context,
    TaskActionType actionType,
  ) async {
    // 获取实例管理器
    final instanceManager = Provider.of<InstanceManager>(context, listen: false);
    
    // 根据操作类型设置标题和按钮文本
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
              // 操作所有实例的任务
              buildDialogOption(
                context,
                allInstancesText,
                onTap: () {
                  print(allInstancesText);
                  Navigator.pop(context);
                  // TODO: 实现操作所有实例任务的逻辑
                },
              ),
              const SizedBox(height: 8),
              // 分隔线
              Container(height: 1, color: colorScheme.surfaceContainerHighest),
              const SizedBox(height: 8),
              // 目标实例列表
              ...targetInstances.map((instance) => Column(
                children: [
                  buildDialogOption(
                    context,
                    '$instanceActionText${instance.name}" 的任务',
                    onTap: () {
                      print('$instanceActionText${instance.name}" 的任务');
                      Navigator.pop(context);
                      // TODO: 实现操作指定实例任务的逻辑
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

  /// 构建对话框选项
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
}