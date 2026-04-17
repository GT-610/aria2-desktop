import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n/l10n.dart';
import '../../models/aria2_instance.dart';
import '../../services/instance_manager.dart';
import '../remote_instance_settings_page.dart';
import '../remote_instance_status_page.dart';
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
        tooltip: l10n.addInstanceTooltip,
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
          onOpenRemoteSettings: _handleOpenRemoteSettings,
          onOpenRemoteStatus: _handleOpenRemoteStatus,
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
    final l10n = AppLocalizations.of(context)!;
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
                  ? l10n.instanceReachable
                  : l10n.instanceOfflineUnreachable,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.checkStatusFailed('$e')),
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
    final l10n = AppLocalizations.of(context)!;
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
            SnackBar(content: Text(l10n.disconnectedSuccessfully)),
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

  Future<void> _handleOpenRemoteSettings(Aria2Instance instance) async {
    final l10n = AppLocalizations.of(context)!;
    if (instance.type != InstanceType.remote) {
      return;
    }

    if (instance.status != ConnectionStatus.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.remoteSettingsRequiresConnectedInstance),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RemoteInstanceSettingsPage(instance: instance),
      ),
    );
  }

  Future<void> _handleOpenRemoteStatus(Aria2Instance instance) async {
    final l10n = AppLocalizations.of(context)!;
    if (instance.type != InstanceType.remote) {
      return;
    }

    if (instance.status != ConnectionStatus.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.remoteStatusMaintenanceRequiresConnectedInstance),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RemoteInstanceStatusPage(instance: instance),
      ),
    );
  }

  Future<void> _handleDeleteInstance(Aria2Instance instance) async {
    final l10n = AppLocalizations.of(context)!;
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.confirmDeleteInstance(instance.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.delete,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.instanceDeletedSuccess)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.failedToDeleteInstance('$e')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _openInstanceDialog({Aria2Instance? instance}) async {
    final l10n = AppLocalizations.of(context)!;
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
              SnackBar(content: Text(l10n.instanceUpdatedSuccess)),
            );
          }
        } else {
          await instanceManager.addInstance(result);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.instanceAddedSuccess)));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.operationFailed('$e')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleConnectInstance(Aria2Instance instance) async {
    final l10n = AppLocalizations.of(context)!;
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    try {
      final connectSuccess = await instanceManager.connectInstance(instance);
      if (mounted) {
        if (connectSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.successConnected(instance.name))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.connectionFailedCheckConfig),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.connectionFailedError('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
