import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n/l10n.dart';
import '../../models/aria2_instance.dart';
import '../../services/instance_manager.dart';
import 'components/instance_card.dart';
import 'components/instance_dialog.dart';

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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.instance)),
      body: _buildInstanceListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openInstanceDialog(),
        tooltip: 'Add instance',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInstanceListView() {
    final l10n = AppLocalizations.of(context)!;
    final instanceManager = Provider.of<InstanceManager>(context);
    final instances = instanceManager.instances;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (instances.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
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
          SnackBar(
            content: Text(
              isOnline
                  ? 'Instance is reachable'
                  : 'Instance is offline or unreachable',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check instance status: $e'),
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

      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );

      if (instance.status == ConnectionStatus.connected) {
        await instanceManager.disconnectInstance(instance);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disconnected successfully')),
          );
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

  void _handleEditInstance(Aria2Instance instance) {
    _openInstanceDialog(instance: instance);
  }

  Future<void> _handleDeleteInstance(Aria2Instance instance) async {
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete instance'),
        content: Text('Delete instance "${instance.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (instance.status == ConnectionStatus.connected) {
          await instanceManager.disconnectInstance(instance);
        }

        await instanceManager.deleteInstance(instance.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Instance deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete instance: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _openInstanceDialog({Aria2Instance? instance}) async {
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
          await instanceManager.updateInstance(result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Instance updated successfully')),
            );
          }
        } else {
          await instanceManager.addInstance(result);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Instance added successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Operation failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleConnectInstance(Aria2Instance instance) async {
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    try {
      final connectSuccess = await instanceManager.connectInstance(instance);
      if (mounted) {
        if (connectSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${instance.name} successfully'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection failed. Check the instance settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
