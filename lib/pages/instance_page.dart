import 'package:flutter/material.dart';
import '../models/aria2_instance.dart';
import '../managers/instance_manager.dart';
import '../components/instance_dialog.dart';

class InstancePage extends StatefulWidget {
  const InstancePage({super.key});

  @override
  State<InstancePage> createState() => _InstancePageState();
}

class _InstancePageState extends State<InstancePage> {
  final InstanceManager _instanceManager = InstanceManager();
  List<Aria2Instance> _instances = [];
  Aria2Instance? _selectedInstance;
  bool _isLoading = true;
  final Map<String, bool> _instanceStatus = {}; // 存储实例在线状态

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // 初始化
  Future<void> _initialize() async {
    try {
      await _instanceManager.initialize();
      _loadInstances();
    } catch (e) {
      print('初始化失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 加载实例列表
  void _loadInstances() {
    final instances = _instanceManager.getInstances();
    setState(() {
      _instances = instances;
      // 初始化状态映射
      for (final instance in instances) {
        _instanceStatus[instance.id] = instance.isActive;
      }
    });
    
    // 异步检查所有实例状态
    for (final instance in instances) {
      _checkInstanceStatus(instance);
    }
  }

  // 检查实例在线状态
  Future<void> _checkInstanceStatus(Aria2Instance instance) async {
    try {
      final isOnline = await _instanceManager.checkInstanceOnline(instance);
      if (mounted) {
        setState(() {
          _instanceStatus[instance.id] = isOnline;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _instanceStatus[instance.id] = false;
        });
      }
    }
  }

  // 添加实例
  Future<void> _addInstance() async {
    final result = await showDialog<Aria2Instance>(
      context: context, 
      builder: (context) => const InstanceDialog(),
    );

    if (result != null) {
      try {
        await _instanceManager.addInstance(result);
        _loadInstances();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('实例添加成功')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加实例失败: $e')),
        );
      }
    }
  }

  // 编辑实例
  Future<void> _editInstance() async {
    if (_selectedInstance == null) return;

    final result = await showDialog<Aria2Instance>(
      context: context,
      builder: (context) => InstanceDialog(instance: _selectedInstance),
    );

    if (result != null) {
      try {
        await _instanceManager.updateInstance(result);
        _loadInstances();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('实例更新成功')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新实例失败: $e')),
        );
      }
    }
  }

  // 删除实例
  Future<void> _deleteInstance() async {
    if (_selectedInstance == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除实例 "${_selectedInstance!.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _instanceManager.deleteInstance(_selectedInstance!.id);
        _loadInstances();
        setState(() {
          _selectedInstance = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('实例删除成功')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除实例失败: $e')),
        );
      }
    }
  }

  // 连接/断开实例
  Future<void> _toggleConnection(Aria2Instance instance) async {
    try {
      if (instance.isActive) {
        // 断开连接
        await _instanceManager.disconnectInstance();
        if (mounted) {
          _loadInstances();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已断开连接')),
          );
        }
      } else {
        // 连接实例
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('正在连接...')),
          );
        }
        final success = await _instanceManager.connectInstance(instance);
        if (mounted) {
          if (success) {
            _loadInstances();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('连接成功')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('连接失败，请检查实例配置')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 实例操作工具栏 - Material You 风格
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(bottom: BorderSide(color: colorScheme.surfaceVariant)),
                  ),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _addInstance,
                        icon: const Icon(Icons.add),
                        label: const Text('添加实例'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _selectedInstance != null ? _editInstance : null,
                        icon: const Icon(Icons.edit),
                        label: const Text('编辑'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        enabled: _selectedInstance != null,
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _selectedInstance != null ? _deleteInstance : null,
                        icon: const Icon(Icons.delete),
                        label: const Text('删除'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        enabled: _selectedInstance != null,
                      ),
                    ],
                  ),
                ),
                // 实例列表 - Material You 风格
                Expanded(
                  child: _instances.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.settings_remote_outlined, 
                                  size: 64, color: colorScheme.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text('暂无实例', style: theme.textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text('点击 "添加实例" 按钮开始使用', 
                                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _instances.length,
                          itemBuilder: (context, index) {
                            final instance = _instances[index];
                            final isOnline = _instanceStatus[instance.id] ?? false;
                            final isActive = instance.isActive;
                            final isSelected = _selectedInstance?.id == instance.id;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                              elevation: 2,
                              shadowColor: Colors.black.withValues(alpha: 0.1),
                              surfaceTintColor: colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isSelected
                                    ? BorderSide(color: colorScheme.primary, width: 2)
                                    : BorderSide.none,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    _selectedInstance = instance;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // 状态指示器
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive ? colorScheme.primary : 
                                                 (isOnline ? colorScheme.secondary : colorScheme.error),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isActive ? colorScheme.primary.withValues(alpha: 0.3) :
                                                     (isOnline ? colorScheme.secondary.withValues(alpha: 0.3) : colorScheme.error.withValues(alpha: 0.3)),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // 实例信息
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  instance.name,
                                                  style: theme.textTheme.titleMedium,
                                                ),
                                                const SizedBox(width: 8),
                                                Chip(
                                                  label: Text(
                                                    instance.type == InstanceType.local ? '本地' : '远程',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  backgroundColor: colorScheme.surfaceContainerHighest,
                                                  padding: const EdgeInsets.all(0),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${instance.protocol}://${instance.host}:${instance.port}',
                                              style: TextStyle(
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            // 移除了密钥显示
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // 连接按钮
                                      SegmentedButton<String>(
                                        segments: [
                                          ButtonSegment(
                                            value: isActive ? 'disconnect' : 'connect',
                                            label: Text(isActive ? '断开' : '连接'),
                                          ),
                                        ],
                                        selected: {isActive ? 'disconnect' : 'connect'},
                                        onSelectionChanged: (newSelection) {
                                          _toggleConnection(instance);
                                        },
                                        style: SegmentedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          backgroundColor: colorScheme.surfaceContainerHighest,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}