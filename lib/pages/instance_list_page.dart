import 'package:flutter/material.dart';
import '../models/aria2_instance.dart';
import '../services/instance_manager.dart';
import 'instance_edit_page.dart';

class InstanceListPage extends StatefulWidget {
  final InstanceManager instanceManager;

  const InstanceListPage({Key? key, required this.instanceManager}) : super(key: key);

  @override
  _InstanceListPageState createState() => _InstanceListPageState();
}

class _InstanceListPageState extends State<InstanceListPage> {
  @override
  void initState() {
    super.initState();
    // 注册监听器
    widget.instanceManager.addListener(_onInstancesChanged);
  }

  @override
  void dispose() {
    widget.instanceManager.removeListener(_onInstancesChanged);
    super.dispose();
  }

  void _onInstancesChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('实例管理'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addInstance,
            tooltip: '添加实例',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.instanceManager.instances.length,
        itemBuilder: (context, index) {
          final instance = widget.instanceManager.instances[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(
                instance.name,
                style: TextStyle(
                  fontWeight: instance.isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${instance.type == InstanceType.local ? '本地' : '远程'} | ${instance.protocol}://${instance.host}:${instance.port}'),
                  if (instance.secret.isNotEmpty) Text('已设置密钥'),
                  if (instance.type == InstanceType.local && instance.aria2Path != null) 
                    Text('路径: ${instance.aria2Path}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton(
                    itemBuilder: (context) {
                      final menuItems = [
                        PopupMenuItem(
                          child: Text('编辑'),
                          onTap: () => _editInstance(instance),
                        ),
                      ];
                      
                      if (widget.instanceManager.instances.length > 1) {
                        menuItems.add(
                          PopupMenuItem(
                            child: Text('删除'),
                            onTap: () => _deleteInstance(instance),
                          ),
                        );
                      }
                      
                      return menuItems;
                    },
                  ),
                ],
              ),
              leading: instance.isActive
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : Icon(Icons.circle_outlined),
              onTap: () {
                if (!instance.isActive) {
                  _activateInstance(instance);
                }
              },
            ),
          );
        },
      ),
    );
  }

  /// 添加实例
  void _addInstance() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstanceEditPage(
          instanceManager: widget.instanceManager,
        ),
      ),
    );
    
    if (result == true) {
      // 可以在这里显示成功提示
    }
  }

  /// 编辑实例
  void _editInstance(Aria2Instance instance) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstanceEditPage(
          instance: instance,
          instanceManager: widget.instanceManager,
        ),
      ),
    );
    
    if (result == true) {
      // 可以在这里显示成功提示
    }
  }

  /// 删除实例
  void _deleteInstance(Aria2Instance instance) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('删除实例'),
          content: Text('确定要删除实例 "${instance.name}" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await widget.instanceManager.deleteInstance(instance.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('实例删除成功')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              },
              child: Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// 激活实例
  void _activateInstance(Aria2Instance instance) async {
    try {
      await widget.instanceManager.setActiveInstance(instance.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到实例 "${instance.name}"')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换失败: $e')),
      );
    }
  }
}