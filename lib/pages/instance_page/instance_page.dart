import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/aria2_instance.dart';
import '../../services/instance_manager.dart';
import 'components/instance_dialog.dart';
import 'components/instance_card.dart';
import '../../utils/logging.dart';

// Expand InstanceManager to support notification mechanism
class NotifiableInstanceManager extends ChangeNotifier with Loggable {
  final InstanceManager _manager = InstanceManager();
  List<Aria2Instance> _instances = [];
  Aria2Instance? _activeInstance;

  NotifiableInstanceManager() {
    initLogger();
  }

  List<Aria2Instance> get instances => _instances;
  Aria2Instance? get activeInstance => _activeInstance;

  Future<void> initialize() async {
    await _manager.initialize();
    _loadInstances();
  }

  void _loadInstances() {
    _instances = _manager.instances;
    _activeInstance = _manager.activeInstance;
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

  // Start local process
  Future<bool> startLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local) return false;
    
    try {
      logger.i('Starting local process for instance: ${instance.name}');
      final success = await _manager.startLocalProcess(instance);
      if (success) {
        _loadInstances();
        logger.i('Local process started successfully for instance: ${instance.name}');
      }
      return success;
    } catch (e) {
      logger.e('Failed to start local process', error: e);
      return false;
    }
  }

  // Stop local process
  Future<bool> stopLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local) return false;
    
    try {
      logger.i('Stopping local process for instance: ${instance.name}');
      final success = await _manager.stopLocalProcess(instance);
      if (success) {
        _loadInstances();
        logger.i('Local process stopped successfully for instance: ${instance.name}');
      }
      return success;
    } catch (e) {
      logger.e('Failed to stop local process', error: e);
      return false;
    }
  }

  // Add connection test method - now directly using manager's implementation
  Future<bool> checkConnection(Aria2Instance instance) async {
    return await _manager.checkConnection(instance);
  }

  // Update instance status
  void updateInstanceStatus(String instanceId, ConnectionStatus status) {
    // Update in both local cache and manager
    final index = _instances.indexWhere((instance) => instance.id == instanceId);
    if (index != -1) {
      _instances[index] = _instances[index].copyWith(status: status);
      _manager.updateInstanceInList(instanceId, status);
      notifyListeners();
    }
  }
  
  // Get instance by ID
  Aria2Instance? getInstanceById(String instanceId) {
    return _instances.firstWhere(
      (instance) => instance.id == instanceId,
      // ignore: cast_from_null_always_fails
      orElse: () => null as Aria2Instance,
    );
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

class __InstancePageContentState extends State<_InstancePageContent> with Loggable {
  Aria2Instance? _selectedInstance;
  bool _isRefreshing = false;
  bool _isConnectionInProgress = false;
  final Map<String, bool> _isStatusChecking = {};

  @override
  void initState() {
    super.initState();
    initLogger();
    logger.i('Instance page initialized');
  }

  Future<void> _refreshInstances() async {
    logger.i('Refreshing instances list');
    setState(() {
      _isRefreshing = true;
    });
    try {
      final manager = Provider.of<NotifiableInstanceManager>(context, listen: false);
      await manager.initialize();
      logger.d('Instances list refreshed successfully');
    } catch (e) {
      logger.e('Failed to refresh instances list', error: e);
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
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
      logger.i('${instance.id.isEmpty ? 'Creating' : 'Updating'} instance: ${instance.name}');

      // Save instance
      if (instance.id.isEmpty) {
        logger.d('开始调用addInstance方法添加新实例');
        await manager.addInstance(instance);
        logger.d('addInstance方法调用完成');
        logger.i('Instance created: ${instance.name}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('实例添加成功'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        logger.d('开始调用updateInstance方法更新实例');
        await manager.updateInstance(instance);
        logger.d('updateInstance方法调用完成');
        logger.i('Instance updated: ${instance.name}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('实例更新成功'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      logger.e('Failed to save instance', error: e);
      logger.e('错误类型: ${e.runtimeType}');
      _showErrorDialog('Save failed', e.toString());
    }
  }

  Future<void> _deleteInstance(String id) async {
    final manager = Provider.of<NotifiableInstanceManager>(context, listen: false);
    try {
      logger.i('Deleting instance with id: $id');
      await manager.deleteInstance(id);
      
      if (_selectedInstance?.id == id) {
        setState(() {
          _selectedInstance = null;
        });
      }
      
      logger.i('Instance deleted successfully: $id');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instance deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      logger.e('Failed to delete instance: $id', error: e);
      _showErrorDialog('Delete failed', e.toString());
    }
  }

  Future<void> _toggleConnection(Aria2Instance instance) async {
    if (_isConnectionInProgress) {
      logger.d('Connection operation already in progress, skipping');
      return;
    }

    final manager = Provider.of<NotifiableInstanceManager>(context, listen: false);
    
    try {
        final isActive = manager.activeInstance?.id == instance.id;
        logger.i('${isActive ? 'Disconnecting from' : 'Connecting to'} instance: ${instance.name}');
        
        setState(() {
          _isConnectionInProgress = true;
          // 仅设置UI状态，实际状态在manager方法中处理
          manager.updateInstanceStatus(instance.id, isActive ? ConnectionStatus.disconnected : ConnectionStatus.connecting);
        });

        if (isActive) {
        // Disconnect logic - 断开连接逻辑已在manager中处理状态更新
        await manager.disconnectInstance();
        logger.i('Disconnected from instance: ${instance.name}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Disconnected'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        // Connect logic - 使用manager的connectInstance方法，它会处理连接测试和状态更新
        final success = await manager.connectInstance(instance);
        logger.d('Connect operation result for instance ${instance.name}: $success');
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connection successful'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // Connection failed - 保持本地进程启动功能
            logger.w('Failed to connect to instance: ${instance.name}');
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to connect to instance, please check configuration and network'),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
            
            // For local instances, try to start the process
            if (instance.type == InstanceType.local) {
              final shouldStartProcess = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Start Local Process'),
                  content: const Text('Connection failed, would you like to start Aria2 local process?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Start'),
                    ),
                  ],
                ),
              ) ?? false;
              
              if (shouldStartProcess) {
                logger.d('User requested to start local process for instance: ${instance.name}');
                _startLocalProcess(instance, manager);
              }
            }
          }
        }
      }
    } catch (e) {
      logger.e('Connection operation failed', error: e);
      if (mounted) {
        manager.updateInstanceStatus(instance.id, ConnectionStatus.failed);
        _showErrorDialog('Operation failed', e.toString());
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
    if (instance.type != InstanceType.local) {
      logger.w('Attempted to start local process for non-local instance: ${instance.name}');
      return;
    }
    
    try {
      logger.i('Starting local process for instance: ${instance.name}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Starting local process...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Call method to start local process
      final processStarted = await manager.startLocalProcess(instance);
      logger.d('Local process start command result: $processStarted');
      
      if (!processStarted) {
        logger.w('Local process start command failed for instance: ${instance.name}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to execute local process start command'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      // Wait for process to start
      logger.d('Waiting for process to start...');
      await Future.delayed(const Duration(seconds: 3));
      
      // Try to reconnect
      if (mounted) {
        manager.updateInstanceStatus(instance.id, ConnectionStatus.connecting);
        final success = await manager.connectInstance(instance);
        logger.d('Reconnection attempt after process start: $success');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Local process started and connected successfully' : 'Failed to start process, please check file path'),
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
      logger.e('Failed to start local process', error: e);
      
      if (mounted) {
        manager.updateInstanceStatus(instance.id, ConnectionStatus.failed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start local process: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkInstanceStatus(Aria2Instance instance) async {
    if (_isStatusChecking[instance.id] == true) {
      logger.d('Status check already in progress for instance: ${instance.name}, skipping');
      return;
    }
    
    final manager = Provider.of<NotifiableInstanceManager>(context, listen: false);
    
    setState(() {
      _isStatusChecking[instance.id] = true;
    });
    
    try {
      logger.i('Checking status for instance: ${instance.name}');
      manager.updateInstanceStatus(instance.id, ConnectionStatus.connecting);
      
      final isOnline = await manager.checkConnection(instance);
      logger.d('Status check result for instance ${instance.name}: ${isOnline ? 'online' : 'offline'}');
      
      if (mounted) {
        manager.updateInstanceStatus(
          instance.id, 
          isOnline ? ConnectionStatus.connected : ConnectionStatus.disconnected
        );
      }
    } catch (e) {
      logger.e('Failed to check instance status', error: e);
      
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
    logger.w('Showing error dialog: $title - $message');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
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

                            return InstanceCard(
                              key: ValueKey(instance.id),
                              instance: instance,
                              isActive: isActive,
                              isSelected: isSelected,
                              isChecking: isChecking,
                              isConnectionInProgress: _isConnectionInProgress && isActive,
                              onSelect: (selectedInstance) {
                                setState(() {
                                  _selectedInstance = selectedInstance;
                                });
                              },
                              onCheckStatus: _checkInstanceStatus,
                              onToggleConnection: _toggleConnection,
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