import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../generated/l10n/l10n.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.instance)),
      body: _buildContent(),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildContent() {
    return _buildInstanceListView();
  }

  Widget _buildInstanceListView() {
    final l10n = AppLocalizations.of(context)!;
    final instanceManager = Provider.of<InstanceManager>(context);
    final instances = instanceManager.instances;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return instances.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 64,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(l10n.noSavedInstances, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text(
                  l10n.clickToAddInstance,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: instances.length,
            itemBuilder: (context, index) {
              final instance = instances[index];

              return InstanceCard(
                instance: instance,
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

      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final isOnline = await instanceManager.checkConnection(instance);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isOnline ? '实例在线' : '实例离线或无法连接')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查状态失败: $e'), backgroundColor: Colors.red),
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

      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );

      if (instance.status == ConnectionStatus.connected) {
        await instanceManager.disconnectInstance(instance);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已断开连接')));
        }
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

  // Handle edit instance
  void _handleEditInstance(Aria2Instance instance) {
    _openInstanceDialog(instance: instance);
  }

  // Handle delete instance
  Future<void> _handleDeleteInstance(Aria2Instance instance) async {
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
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
            child: Text(
              '删除',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 如果实例已连接，先断开连接
        if (instance.status == ConnectionStatus.connected) {
          await instanceManager.disconnectInstance(instance);
        }

        await instanceManager.deleteInstance(instance.id);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('实例删除成功')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // Open edit or add instance dialog
  void _openInstanceDialog({Aria2Instance? instance}) async {
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    final result = await showDialog<Aria2Instance>(
      context: context,
      builder: (context) => InstanceDialog(instance: instance),
    );

    if (result != null) {
      try {
        if (instance != null) {
          // Update existing instance
          await instanceManager.updateInstance(result);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('实例更新成功')));
          }
        } else {
          // Add new instance
          await instanceManager.addInstance(result);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('实例添加成功')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
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

  // Connect to instance
  Future<void> _handleConnectInstance(Aria2Instance instance) async {
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    try {
      final connectSuccess = await instanceManager.connectInstance(instance);
      if (mounted) {
        if (connectSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('成功连接到实例: ${instance.name}')));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
