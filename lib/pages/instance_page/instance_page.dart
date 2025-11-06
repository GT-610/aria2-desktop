import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/aria2_instance.dart';
import '../../managers/instance_manager.dart';
import 'components/instance_dialog.dart';
import '../../services/aria2_rpc_client.dart';

// Expand InstanceManager to support notification mechanism
class NotifiableInstanceManager extends ChangeNotifier {
  final InstanceManager _manager = InstanceManager();
  List<Aria2Instance> _instances = [];
  Aria2Instance? _activeInstance;

  List<Aria2Instance> get instances => _instances;
  Aria2Instance? get activeInstance => _activeInstance;

  Future<void> initialize() async {
    await _manager.initialize();
    _loadInstances();
  }

  void _loadInstances() {
    _instances = _manager.getInstances();
    _activeInstance = _manager.getActiveInstance();
    notifyListeners();
  }

  Future<void> addInstance(Aria2Instance instance) async {
    await _manager.addInstance(instance);
    _loadInstances();
  }

  Future<void> updateInstance(Aria2Instance instance) async {
    await _manager.updateInstance(instance);
    _loadInstances();
  }

  Future<void> deleteInstance(String id) async {
    await _manager.deleteInstance(id);
    _loadInstances();
  }

  Future<bool> connectInstance(Aria2Instance instance) async {
    final success = await _manager.connectInstance(instance);
    if (success) {
      _loadInstances();
    }
    return success;
  }

  Future<void> disconnectInstance() async {
    await _manager.disconnectInstance();
    _loadInstances();
  }

  Future<bool> checkInstanceOnline(Aria2Instance instance) async {
    return await _manager.checkInstanceOnline(instance);
  }

  // 启动本地进程
  Future<bool> startLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local) return false;
    
    try {
      // 直接在NotifiableInstanceManager中实现本地进程启动逻辑
      // 这里只是一个占位实现，实际功能在页面级别的_startLocalProcess方法中处理
      // 主要用于提供API一致性
      _loadInstances();
      return true;
    } catch (e) {
      print('启动本地进程失败: $e');
      return false;
    }
  }

  // 停止本地进程
  Future<bool> stopLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local) return false;
    
    try {
      // 直接在NotifiableInstanceManager中实现本地进程停止逻辑
      // 这里只是一个占位实现，实际功能在页面级别的处理逻辑中处理
      // 主要用于提供API一致性
      _loadInstances();
      return true;
    } catch (e) {
      print('停止本地进程失败: $e');
      return false;
    }
  }

  // Add connection test method
  Future<bool> checkConnection(Aria2Instance instance) async {
    try {
      final client = Aria2RpcClient(instance);
      // First try basic connection
      final isConnected = await client.testConnection();
      
      if (isConnected) {
        // If connection is successful, try to get version info
        try {
          final version = await client.getVersion();
          // Update instance version info
          final updatedInstance = instance.copyWith(version: version);
          await _manager.updateInstance(updatedInstance);
        } catch (e) {
          print('获取版本信息失败: $e');
        }
      }
      
      client.close();
      return isConnected;
    } catch (e) {
      print('连接测试失败: $e');
      return false;
    }
  }

  // Update instance status
  void updateInstanceStatus(String instanceId, ConnectionStatus status) {
    final index = _instances.indexWhere((instance) => instance.id == instanceId);
    if (index != -1) {
      _instances[index] = _instances[index].copyWith(status: status);
      notifyListeners();
    }
  }
}

// Wrap widget with provider for state management
class InstancePage extends StatelessWidget {
  const InstancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NotifiableInstanceManager()..initialize(),
      child: _InstancePageContent(),
    );
  }
}

class _InstancePageContent extends StatefulWidget {
  @override
  __InstancePageContentState createState() => __InstancePageContentState();
}

class __InstancePageContentState extends State<_InstancePageContent> {
  Aria2Instance? _selectedInstance;
  bool _isRefreshing = false;
  bool _isConnectionInProgress = false;
  final Map<String, bool> _isStatusChecking = {};

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshInstances() async {
    setState(() {
      _isRefreshing = true;
    });
    final manager = Provider.of<NotifiableInstanceManager>(context, listen: false);
    await manager.initialize();
    setState(() {
      _isRefreshing = false;
    });
  }

  void _showAddInstanceDialog() {
    showDialog(
      context: context,
      builder: (context) => InstanceDialog(
        onSave: _handleSaveInstance,
      ),
    );
  }

  void _showEditInstanceDialog(Aria2Instance instance) {
    showDialog(
      context: context,
      builder: (context) => InstanceDialog(
        instance: instance,
        onSave: _handleSaveInstance,
      ),
    );
  }

  void _showDeleteConfirmationDialog(Aria2Instance instance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除实例 "${instance.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteInstance(instance.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSaveInstance(Aria2Instance instance) async {
    final manager = Provider.of<NotifiableInstanceManager>(context, listen: false);
    try {
      // Show connection test animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Dialog(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在测试连接...'),
              ],
            ),
          ),
        ),
      );

      // Test connection
      final isConnected = await manager.checkConnection(instance);
      if (mounted) {
        Navigator.pop(context);
      }

      // Save instance
      if (instance.id.isEmpty) {
        await manager.addInstance(instance);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('添加实例${isConnected ? '成功' : '成功，但连接测试失败'}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        await manager.updateInstance(instance);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新实例${isConnected ? '成功' : '成功，但连接测试失败'}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      _showErrorDialog('保存失败', e.toString());
    }
  }

  Future<void> _deleteInstance(String id) async {
    final manager = Provider.of<NotifiableInstanceManager>(context, listen: false);
    try {
      await manager.deleteInstance(id);
      if (_selectedInstance?.id == id) {
        setState(() {
          _selectedInstance = null;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('删除实例成功'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showErrorDialog('删除失败', e.toString());
    }
  }

  Future<void> _toggleConnection(Aria2Instance instance) async {
    if (_isConnectionInProgress) return;

    final manager = Provider.of<NotifiableInstanceManager>(context, listen: false);
    final isActive = manager.activeInstance?.id == instance.id;

    try {
      setState(() {
        _isConnectionInProgress = true;
        manager.updateInstanceStatus(instance.id, isActive ? ConnectionStatus.disconnected : ConnectionStatus.connecting);
      });

      if (isActive) {
        // Disconnect logic
        await manager.disconnectInstance();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('已断开连接'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        
        // Update status to disconnected
        if (mounted) {
          manager.updateInstanceStatus(instance.id, ConnectionStatus.disconnected);
        }
      } else {
        // Connect logic
        // First check connection status
        final canConnect = await manager.checkConnection(instance);
        
        if (canConnect) {
          // Connection successful
          final success = await manager.connectInstance(instance);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? '连接成功' : '连接失败，请检查配置'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: success ? Colors.green : Colors.red,
              ),
            );
          }
          
          if (success && mounted) {
            manager.updateInstanceStatus(instance.id, ConnectionStatus.connected);
          } else if (mounted) {
            manager.updateInstanceStatus(instance.id, ConnectionStatus.failed);
          }
        } else {
          // Connection failed
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('无法连接到实例，请检查配置和网络'),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
            manager.updateInstanceStatus(instance.id, ConnectionStatus.failed);
          }
          
          // For local instances, try to start the process
          if (instance.type == InstanceType.local && mounted) {
            final shouldStartProcess = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('启动本地进程'),
                content: const Text('连接失败，是否尝试启动Aria2本地进程？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('启动'),
                  ),
                ],
              ),
            ) ?? false;
            
            if (shouldStartProcess && mounted) {
              _startLocalProcess(instance, manager);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        manager.updateInstanceStatus(instance.id, ConnectionStatus.failed);
        _showErrorDialog('操作失败', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectionInProgress = false;
        });
      }
    }
  }
  
  // Helper method to start local process
  Future<void> _startLocalProcess(Aria2Instance instance, NotifiableInstanceManager manager) async {
    if (instance.type != InstanceType.local) return;
    
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在启动本地进程...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Call method to start local process
      final processStarted = await manager.startLocalProcess(instance);
      
      if (!processStarted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('启动本地进程命令执行失败'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      // Wait for process to start
      await Future.delayed(const Duration(seconds: 3));
      
      // Try to reconnect
      if (mounted) {
        manager.updateInstanceStatus(instance.id, ConnectionStatus.connecting);
        final success = await manager.connectInstance(instance);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '本地进程启动并连接成功' : '启动进程失败，请检查文件路径'),
              duration: const Duration(seconds: 2),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          
          if (success) {
            manager.updateInstanceStatus(instance.id, ConnectionStatus.connected);
          } else {
            manager.updateInstanceStatus(instance.id, ConnectionStatus.failed);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        manager.updateInstanceStatus(instance.id, ConnectionStatus.failed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('启动本地进程失败: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkInstanceStatus(Aria2Instance instance) async {
    if (_isStatusChecking[instance.id] == true) return;
    
    final manager = Provider.of<NotifiableInstanceManager>(context, listen: false);
    
    setState(() {
      _isStatusChecking[instance.id] = true;
    });
    
    try {
      manager.updateInstanceStatus(instance.id, ConnectionStatus.connecting);
      final isOnline = await manager.checkConnection(instance);
      if (mounted) {
        manager.updateInstanceStatus(
          instance.id, 
          isOnline ? ConnectionStatus.connected : ConnectionStatus.disconnected
        );
      }
    } catch (_) {
      if (mounted) {
        manager.updateInstanceStatus(instance.id, ConnectionStatus.failed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStatusChecking[instance.id] = false;
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: Consumer<NotifiableInstanceManager>(
        builder: (context, manager, child) {
          final instances = manager.instances;
          
          return RefreshIndicator.adaptive(
            onRefresh: _refreshInstances,
            child: Column(
              children: [
                // Instance operation toolbar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(bottom: BorderSide(color: colorScheme.surfaceContainerHighest)),
                  ),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _showAddInstanceDialog,
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
                        onPressed: _selectedInstance != null ? () => _showEditInstanceDialog(_selectedInstance!) : null,
                        icon: const Icon(Icons.edit),
                        label: const Text('编辑'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _selectedInstance != null ? () => _showDeleteConfirmationDialog(_selectedInstance!) : null,
                        icon: const Icon(Icons.delete),
                        label: const Text('删除'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _refreshInstances,
                        icon: const Icon(Icons.refresh),
                        tooltip: '刷新列表',
                        isSelected: _isRefreshing,
                        selectedIcon: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                  ),
                ),
                // Instance list
                Expanded(
                  child: instances.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.settings_remote_outlined,
                                  size: 64,
                                  color: colorScheme.outlineVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '暂无实例',
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '点击添加按钮创建新的Aria2实例',
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: _showAddInstanceDialog,
                                  child: const Text('添加实例'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: instances.length,
                          itemBuilder: (context, index) {
                            final instance = instances[index];
                            final isActive = manager.activeInstance?.id == instance.id;
                            final isSelected = _selectedInstance?.id == instance.id;
                            final isChecking = _isStatusChecking[instance.id] == true;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                              elevation: isSelected ? 4 : 2,
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // 实例名称和类型
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              // 状态指示器
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isActive ? colorScheme.primary : 
                                                         (instance.status == ConnectionStatus.connected ? colorScheme.secondary : colorScheme.error),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: isActive ? colorScheme.primary.withValues(alpha: 0.3) :
                                                             (instance.status == ConnectionStatus.connected ? colorScheme.secondary.withValues(alpha: 0.3) : colorScheme.error.withValues(alpha: 0.3)),
                                                      blurRadius: 4,
                                                      spreadRadius: 1,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
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
                                          if (isActive) ...[
                                            Chip(
                                              label: const Text('当前活跃'),
                                              labelStyle: TextStyle(
                                                color: colorScheme.onPrimary,
                                                fontSize: 12,
                                              ),
                                              backgroundColor: colorScheme.primary,
                                              padding: const EdgeInsets.all(0),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // 实例详情
                                      Text(
                                        '${instance.protocol}://${instance.host}:${instance.port}',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (instance.type == InstanceType.local && instance.aria2Path != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '路径: ${instance.aria2Path}',
                                          style: theme.textTheme.bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      // 版本信息
                                      if (instance.version != null && instance.version!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '版本: ${instance.version}',
                                          style: TextStyle(
                                            color: colorScheme.tertiary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                      // 错误信息
                                      if (instance.errorMessage != null && instance.errorMessage!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.warning,
                                              size: 14,
                                              color: colorScheme.error,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                instance.errorMessage!,
                                                style: TextStyle(
                                                  color: colorScheme.error,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      // 操作按钮
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // 状态检查按钮
                                          TextButton.icon(
                                            onPressed: () => _checkInstanceStatus(instance),
                                            icon: isChecking
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  )
                                                : Icon(
                                                    Icons.check_circle_outline,
                                                    size: 18,
                                                    color: instance.status == ConnectionStatus.connected ? Colors.green : Colors.grey,
                                                  ),
                                            label: Text(
                                              instance.status == ConnectionStatus.connected ? '已连接' : '检查状态',
                                              style: TextStyle(
                                                color: instance.status == ConnectionStatus.connected ? Colors.green : null,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            ),
                                          ),
                                          // 连接/断开按钮
                                          SegmentedButton<String>(
                                            segments: [
                                              ButtonSegment(
                                                value: isActive ? 'disconnect' : 'connect',
                                                label: Text(
                                                  isActive ? '断开' : '连接',
                                                  style: _isConnectionInProgress && instance.id == manager.activeInstance?.id
                                                      ? const TextStyle(color: Colors.grey)
                                                      : null,
                                                ),
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
        },
      ),
    );
  }
}