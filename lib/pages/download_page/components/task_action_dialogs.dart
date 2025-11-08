import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
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
    {VoidCallback? onActionCompleted}
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
                onTap: () async {
                  Navigator.pop(context);
                  await _performActionForAllInstances(context, actionType);
                  onActionCompleted?.call();
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

  /// 对所有实例执行任务操作
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

  /// 对单个实例执行任务操作
  static Future<void> _performActionForInstance(
    Aria2Instance instance,
    TaskActionType actionType,
  ) async {
    try {
      // 简化实现，暂时注释掉实际操作
      // 在实际应用中，需要根据Aria2RpcClient的实际API调整这些方法调用
      print('对实例 ${instance.name} 执行操作: $actionType');
      
      // 此处应该根据Aria2RpcClient的实际API实现相应功能
      // final client = Aria2RpcClient(instance);
      // 根据实际API调用相应方法
      // client.close();
    } catch (e) {
      if (kDebugMode) {
        print('执行任务操作错误: $e');
      }
      // 可以在这里添加错误处理，比如显示错误提示
    }
  }
}