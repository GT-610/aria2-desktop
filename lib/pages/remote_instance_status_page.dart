import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../generated/l10n/l10n.dart';
import '../models/aria2_instance.dart';
import '../services/aria2_rpc_client.dart';
import '../services/download_data_service.dart';
import '../services/instance_manager.dart';
import '../utils/format_utils.dart';

class RemoteInstanceStatusPage extends StatefulWidget {
  final Aria2Instance instance;

  const RemoteInstanceStatusPage({super.key, required this.instance});

  @override
  State<RemoteInstanceStatusPage> createState() => _RemoteInstanceStatusPage();
}

class _RemoteInstanceStatusPage extends State<RemoteInstanceStatusPage> {
  bool _isLoading = true;
  bool _isSavingSession = false;
  bool _isPurgingResults = false;
  String? _loadError;
  _RemoteStatusSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    final client = Aria2RpcClient(widget.instance);
    try {
      final versionInfo = await client.getVersionInfo();
      final globalStat = await client.getGlobalStat();
      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = _RemoteStatusSnapshot.fromRpc(versionInfo, globalStat);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = '$error';
      });
    } finally {
      client.close();
    }
  }

  Future<void> _saveSession() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSavingSession = true;
    });

    final client = Aria2RpcClient(widget.instance);
    try {
      final succeeded = await client.saveSession();
      if (!mounted) {
        return;
      }
      _showSnackBar(
        succeeded ? l10n.saveSessionSuccess : l10n.saveSessionFailed,
        backgroundColor: succeeded ? null : Colors.red,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        l10n.saveSessionFailedWithError('$error'),
        backgroundColor: Colors.red,
      );
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _isSavingSession = false;
        });
      }
    }
  }

  Future<void> _purgeDownloadResults() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.purgeDownloadResults),
        content: Text(l10n.purgeDownloadResultsConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.purgeDownloadResults,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isPurgingResults = true;
    });

    final client = Aria2RpcClient(widget.instance);
    try {
      final succeeded = await client.purgeDownloadResult();
      if (!mounted) {
        return;
      }

      if (succeeded) {
        await _refreshTasks();
        await _loadStatus();
        if (!mounted) {
          return;
        }
        _showSnackBar(l10n.purgeDownloadResultsSuccess);
      } else {
        _showSnackBar(
          l10n.purgeDownloadResultsFailed,
          backgroundColor: Colors.red,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(
        l10n.purgeDownloadResultsFailedWithError('$error'),
        backgroundColor: Colors.red,
      );
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _isPurgingResults = false;
        });
      }
    }
  }

  Future<void> _refreshTasks() async {
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    final downloadDataService = Provider.of<DownloadDataService>(
      context,
      listen: false,
    );
    await downloadDataService.refreshTasks(
      instanceManager.getConnectedInstances(),
    );
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Aria2Instance _currentInstance(BuildContext context) {
    final instanceManager = Provider.of<InstanceManager>(context);
    for (final instance in instanceManager.instances) {
      if (instance.id == widget.instance.id) {
        return instance;
      }
    }
    return widget.instance;
  }

  String _statusText(AppLocalizations l10n, ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return l10n.disconnected;
      case ConnectionStatus.connecting:
        return l10n.connecting;
      case ConnectionStatus.connected:
        return l10n.connected;
      case ConnectionStatus.failed:
        return l10n.failed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentInstance = _currentInstance(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.remoteStatusMaintenance),
        actions: [
          IconButton(
            onPressed: _isLoading || _isSavingSession || _isPurgingResults
                ? null
                : _loadStatus,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: fl.SizedLoading.small,
                  )
                : const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _buildBody(context, l10n, theme, colorScheme, currentInstance),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    Aria2Instance instance,
  ) {
    if (_isLoading && _snapshot == null) {
      return const Center(child: fl.SizedLoading.large);
    }

    if (_loadError != null && _snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.remoteStatusMaintenanceLoadFailed,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadStatus,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.refresh),
              ),
            ],
          ),
        ),
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(context, l10n, theme, colorScheme, instance, snapshot),
        const SizedBox(height: 16),
        _buildSummaryCard(context, l10n, theme, colorScheme, snapshot),
        const SizedBox(height: 16),
        _buildActionsCard(context, l10n, theme, colorScheme),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    Aria2Instance instance,
    _RemoteStatusSnapshot snapshot,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.remoteReadonlyInfo, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _buildInfoRow(l10n.instanceName, instance.name),
            _buildInfoRow(l10n.aria2RpcAddress, instance.rpcUrl),
            _buildInfoRow(
              l10n.statusWithValue(_statusText(l10n, instance.status)),
              '',
              compact: true,
            ),
            _buildInfoRow(l10n.version, snapshot.version),
            const SizedBox(height: 8),
            Text(
              l10n.enabledFeatures,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            snapshot.enabledFeatures.isEmpty
                ? Text(
                    l10n.noEnabledFeatures,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: snapshot.enabledFeatures
                        .map((feature) => Chip(label: Text(feature)))
                        .toList(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    _RemoteStatusSnapshot snapshot,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.remoteStatusSummary, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    colorScheme,
                    l10n.downloadSpeedLabel,
                    '${formatBytes(snapshot.downloadSpeedBytes)}/s',
                    Icons.download_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    colorScheme,
                    l10n.uploadSpeedLabel,
                    '${formatBytes(snapshot.uploadSpeedBytes)}/s',
                    Icons.upload_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    colorScheme,
                    l10n.activeTaskCountLabel,
                    '${snapshot.numActive}',
                    Icons.play_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    colorScheme,
                    l10n.waitingTaskCountLabel,
                    '${snapshot.numWaiting}',
                    Icons.pause_circle_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildMetricTile(
              colorScheme,
              l10n.stoppedTaskCountLabel,
              '${snapshot.numStopped}',
              Icons.stop_circle_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.remoteMaintenanceActions,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isSavingSession || _isPurgingResults
                  ? null
                  : _saveSession,
              icon: _isSavingSession
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: fl.SizedLoading.small,
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(l10n.saveSession),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.purgeDownloadResultsTip,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isSavingSession || _isPurgingResults
                  ? null
                  : _purgeDownloadResults,
              icon: _isPurgingResults
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: fl.SizedLoading.small,
                    )
                  : const Icon(Icons.delete_sweep_outlined),
              label: Text(l10n.purgeDownloadResults),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool compact = false}) {
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    ColorScheme colorScheme,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteStatusSnapshot {
  final String version;
  final List<String> enabledFeatures;
  final int downloadSpeedBytes;
  final int uploadSpeedBytes;
  final int numActive;
  final int numWaiting;
  final int numStopped;

  const _RemoteStatusSnapshot({
    required this.version,
    required this.enabledFeatures,
    required this.downloadSpeedBytes,
    required this.uploadSpeedBytes,
    required this.numActive,
    required this.numWaiting,
    required this.numStopped,
  });

  factory _RemoteStatusSnapshot.fromRpc(
    Map<String, dynamic> versionInfo,
    Map<String, dynamic> globalStat,
  ) {
    final features =
        (versionInfo['enabledFeatures'] as List<dynamic>? ?? const [])
            .map((feature) => feature.toString())
            .where((feature) => feature.trim().isNotEmpty)
            .toList();

    return _RemoteStatusSnapshot(
      version: versionInfo['version']?.toString() ?? '-',
      enabledFeatures: features,
      downloadSpeedBytes:
          int.tryParse(globalStat['downloadSpeed']?.toString() ?? '0') ?? 0,
      uploadSpeedBytes:
          int.tryParse(globalStat['uploadSpeed']?.toString() ?? '0') ?? 0,
      numActive: int.tryParse(globalStat['numActive']?.toString() ?? '0') ?? 0,
      numWaiting:
          int.tryParse(globalStat['numWaiting']?.toString() ?? '0') ?? 0,
      numStopped:
          int.tryParse(globalStat['numStopped']?.toString() ?? '0') ?? 0,
    );
  }
}
