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

  // 构建状态指示灯
  Widget _buildStatusIndicator(ConnectionStatus status, bool isActive) {
    if (!isActive) {
      return Icon(Icons.radio_button_unchecked, color: Colors.grey);
    }
    
    switch (status) {
      case ConnectionStatus.connected:
        return Icon(Icons.radio_button_checked, color: Colors.green);
      case ConnectionStatus.connecting:
        return Icon(Icons.radio_button_checked, color: Colors.yellow);
      case ConnectionStatus.failed:
        return Icon(Icons.radio_button_checked, color: Colors.red);
      case ConnectionStatus.disconnected:
      default:
        return Icon(Icons.radio_button_unchecked, color: Colors.grey);
    }
  }
  
  // 获取状态文本
  String _getStatusText(ConnectionStatus status, bool isActive) {
    if (!isActive) {
      return '未激活';
    }
    
    switch (status) {
      case ConnectionStatus.connected:
        return '已连接';
      case ConnectionStatus.connecting:
        return '连接中';
      case ConnectionStatus.failed:
        return '连接失败';
      case ConnectionStatus.disconnected:
      default:
        return '未连接';
    }
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
              elevation: 2,
              child: InkWell(
                onTap: null,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  leading: _buildStatusIndicator(instance.status, instance.isActive),
                  title: Text(
                    instance.name,
                    style: TextStyle(
                      fontWeight: instance.isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getStatusText(instance.status, instance.isActive)} | ${instance.type == InstanceType.local ? '本地' : '远程'} | ${instance.protocol}://${instance.host}:${instance.port}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (instance.secret.isNotEmpty) Text('已设置密钥'),
                      if (instance.type == InstanceType.local && instance.aria2Path != null) 
                        Text('路径: ${instance.aria2Path}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check_circle_outline),
                        onPressed: () => _activateInstance(instance),
                        tooltip: '激活',
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _editInstance(instance),
                        tooltip: '编辑',
                      ),
                      if (widget.instanceManager.instances.length > 1)
                        IconButton(
                          icon: Icon(Icons.delete_outline),
                          onPressed: () => _deleteInstance(instance),
                          tooltip: '删除',
                        ),
                    ],
                  ),
                ),
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

  // 激活实例
  void _activateInstance(Aria2Instance instance) async {
    try {
      // 先更新状态
      setState(() {
        instance.status = ConnectionStatus.connecting;
      });
      
      await widget.instanceManager.setActiveInstance(instance.id);
      
      // 模拟连接过程，实际应该调用真实的连接API
      Future.delayed(Duration(seconds: 1), () {
        setState(() {
          // 这里简化处理，直接设置为已连接
          // 实际应用中应该根据真实连接结果设置状态
          instance.status = ConnectionStatus.connected;
        });
      });
    } catch (e) {
      setState(() {
        instance.status = ConnectionStatus.failed;
      });
    }
  }
}