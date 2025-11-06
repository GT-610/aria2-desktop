import 'package:flutter/material.dart';
import '../models/aria2_instance.dart';
import '../services/instance_manager.dart';
import '../services/aria2_rpc_client.dart';
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
    
    // 初始化时确保所有实例状态正确，防止错误显示为"连接中"
    _resetInstanceStatuses();
  }
  
  // 重置实例状态，确保没有错误的"连接中"状态
  void _resetInstanceStatuses() {
    for (var instance in widget.instanceManager.instances) {
      if (instance.status == ConnectionStatus.connecting) {
        // 将所有"连接中"状态重置为"未连接"
        final updatedInstance = instance.copyWith(
          status: ConnectionStatus.disconnected,
        );
        widget.instanceManager.updateInstance(updatedInstance);
      }
    }
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
      return Icon(Icons.radio_button_unchecked, color: Colors.grey);
    }
  }
  
  // 获取状态文本
  String _getStatusText(Aria2Instance instance) {
    final status = instance.status;
    final isActive = instance.isActive;
    
    if (!isActive) {
      return '未激活';
    }
    
    switch (status) {
      case ConnectionStatus.connected:
        // 如果有版本号，显示版本号
        if (instance.version != null && instance.version!.isNotEmpty) {
          return '已连接 (${instance.version})';
        }
        return '已连接';
      case ConnectionStatus.connecting:
        return '连接中';
      case ConnectionStatus.failed:
          // 如果有错误信息，显示错误信息
          if (instance.errorMessage != null && instance.errorMessage!.isNotEmpty) {
            return '连接失败 (${instance.errorMessage})';
          }
          return '连接失败';
      case ConnectionStatus.disconnected:
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
                        '${_getStatusText(instance)} | ${instance.type == InstanceType.local ? '本地' : '远程'} | ${instance.protocol}://${instance.host}:${instance.port}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 移除了密钥显示
                      if (instance.type == InstanceType.local && instance.aria2Path != null) 
                        Text('路径: ${instance.aria2Path}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: instance.status == ConnectionStatus.connecting || instance.status == ConnectionStatus.connected
                            ? Icon(Icons.link_off)
                            : Icon(Icons.link),
                        onPressed: () {
                          if (instance.status == ConnectionStatus.connecting || instance.status == ConnectionStatus.connected) {
                            _disconnectInstance(instance);
                          } else {
                            _activateInstance(instance);
                          }
                        },
                        tooltip: instance.status == ConnectionStatus.connecting || instance.status == ConnectionStatus.connected
                            ? '断开连接'
                            : '连接',
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

  // 断开实例连接
  void _disconnectInstance(Aria2Instance instance) {
    // 记录断开前的状态
    final wasConnecting = instance.status == ConnectionStatus.connecting;
    
    setState(() {
      instance.status = ConnectionStatus.disconnected;
      instance.errorMessage = null; // 清除错误信息
    });
    
    // 只有在连接中状态断开时才显示提示
    if (wasConnecting) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已中断当前连接')),
      );
    }
  }
  
  // 激活实例
  void _activateInstance(Aria2Instance instance) async {
    try {
      // 先更新状态
      setState(() {
        instance.status = ConnectionStatus.connecting;
      });
      
      await widget.instanceManager.setActiveInstance(instance.id);
      
      // 创建RPC客户端并进行连接测试
      final rpcClient = Aria2RpcClient(instance);
      
      // 使用getVersion方法验证连接
      final version = await rpcClient.getVersion();
      
      // 连接成功，更新实例状态和版本信息
      setState(() {
        instance.status = ConnectionStatus.connected;
        instance.version = version;
      });
      
      // 关闭客户端
      rpcClient.close();
    } catch (e) {
      // 连接失败，根据异常类型设置不同的错误消息
      String? errorMsg;
      
      // 直接使用异常的toString()，因为我们已经在异常类中定义了适当的错误消息
      if (e is ConnectionFailedException || e is UnauthorizedException) {
        errorMsg = e.toString();
      } else {
        // 其他错误情况
        errorMsg = '未知的连接错误';
      }
      
      setState(() {
        instance.status = ConnectionStatus.failed;
        instance.errorMessage = errorMsg;
      });
    }
  }
}