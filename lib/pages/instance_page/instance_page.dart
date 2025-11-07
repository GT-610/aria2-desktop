import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/instance_manager.dart';
import '../../models/aria2_instance.dart';
import 'components/instance_dialog.dart';
import 'components/instance_card.dart';

class InstancePage extends StatefulWidget {
  const InstancePage({super.key});

  @override
  State<InstancePage> createState() => _InstancePageState();
}

class _InstancePageState extends State<InstancePage> {
  Aria2Instance? _selectedInstance;
  bool _isChecking = false;
  bool _isConnectionInProgress = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实例管理'),
      ),
      body: _buildContent(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildContent() {
    return _buildInstanceListView();
  }

  Widget _buildInstanceListView() {
    final instanceManager = Provider.of<InstanceManager>(context);
    final instances = instanceManager.instances;
    final activeInstance = instanceManager.activeInstance;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return instances.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_outlined, size: 64, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  '暂无保存的实例',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '点击右下角按钮添加新实例',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: instances.length,
            itemBuilder: (context, index) {
              final instance = instances[index];
              final isActive = activeInstance?.id == instance.id;
              
              return InstanceCard(
                instance: instance,
                isActive: isActive,
                isSelected: _selectedInstance?.id == instance.id,
                isChecking: _isChecking,
                isConnectionInProgress: _isConnectionInProgress,
                onSelect: _handleSelectInstance,
                onCheckStatus: _handleCheckStatus,
                onToggleConnection: _handleToggleConnection,
                onEdit: _handleEditInstance,
                onDelete: _handleDeleteInstance,
              );
            },
          );
  }

  void _handleSelectInstance(Aria2Instance instance) {
    setState(() {
      _selectedInstance = instance;
    });
  }

  Future<void> _handleCheckStatus(Aria2Instance instance) async {
    try {
      setState(() {
        _isChecking = true;
      });
      
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      final isOnline = await instanceManager.checkConnection(instance);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isOnline 
              ? '实例在线' 
              : '实例离线或无法连接'
            ),
          ),
        );
      }
    } catch (e) {
      // 移除logger.e调用
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('检查状态失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _handleToggleConnection(Aria2Instance instance) async {
    try {
      setState(() {
        _isConnectionInProgress = true;
      });
      
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      final isActive = instanceManager.activeInstance?.id == instance.id;
      
      if (isActive) {
        await _handleDisconnectInstance();
      } else {
        await _handleConnectInstance(instance);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectionInProgress = false;
        });
      }
    }
  }

  // 处理编辑实例
  void _handleEditInstance(Aria2Instance instance) {
    _openInstanceDialog(instance: instance);
  }

  // 处理删除实例
  Future<void> _handleDeleteInstance(Aria2Instance instance) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除实例 "${instance.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final instanceManager = Provider.of<InstanceManager>(context, listen: false);
        
        // 如果是当前活跃实例，先断开连接
        if (instanceManager.activeInstance?.id == instance.id) {
          await instanceManager.disconnectInstance();
        }
        
        await instanceManager.deleteInstance(instance.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('实例删除成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 打开编辑或添加实例对话框
  void _openInstanceDialog({Aria2Instance? instance}) async {
    final result = await showDialog<Aria2Instance>(
      context: context,
      builder: (context) => InstanceDialog(
        instance: instance,
      ),
    );

    if (result != null) {
      try {
        final instanceManager = Provider.of<InstanceManager>(context, listen: false);
        
        if (instance != null) {
          // 更新现有实例
          await instanceManager.updateInstance(result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('实例更新成功')),
            );
          }
        } else {
          // 添加新实例
          await instanceManager.addInstance(result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('实例添加成功')),
            );
          }
        }
      } catch (e) {
        // 移除logger.e调用
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('操作失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget? _buildFAB() {
    return FloatingActionButton(
      onPressed: () => _openInstanceDialog(),
      tooltip: '添加实例',
      child: const Icon(Icons.add),
    );
  }

  // 连接实例
  Future<void> _handleConnectInstance(Aria2Instance instance) async {
    try {
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      
      // 如果是本地实例，先启动本地进程
      if (instance.type == InstanceType.local) {
        final startSuccess = await instanceManager.startLocalProcess(instance);
        if (!startSuccess && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('启动本地aria2进程失败'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final connectSuccess = await instanceManager.connectInstance(instance);
      if (mounted) {
        if (connectSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成功连接到实例: ${instance.name}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('连接失败，请检查配置'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // 移除logger.e调用
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 断开连接
  Future<void> _handleDisconnectInstance() async {
    try {
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      await instanceManager.disconnectInstance();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已断开连接')),
        );
      }
    } catch (e) {
      // 移除logger.e调用
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('断开连接失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}