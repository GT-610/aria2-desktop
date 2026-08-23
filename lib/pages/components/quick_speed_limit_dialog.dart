import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n/l10n.dart';
import '../../models/settings.dart';
import '../../services/builtin_instance_service.dart';
import '../../services/download_data_service.dart';
import '../../services/instance_manager.dart';
import '../../services/settings_service.dart';

/// Applies the current effective limits to a running built-in instance.
/// Returns false when nothing is running or the push failed.
Future<bool> applySpeedLimitsToBuiltin(BuildContext context) async {
  final instanceManager = context.read<InstanceManager>();
  final builtinInstance = instanceManager.getBuiltinInstance();
  if (builtinInstance == null || !BuiltinInstanceService().isRunning()) {
    return false;
  }
  final settingsService = context.read<SettingsService>();
  final downloadDataService = context.read<DownloadDataService>();
  return settingsService.applySettingsToBuiltin(
    rpcClient: downloadDataService.clientFor(builtinInstance),
  );
}

/// Compact editor for the global up/down limits shown from the status-bar
/// capsule. Values are KB/s; empty input means unlimited.
Future<void> showQuickSpeedLimitDialog(BuildContext context) async {
  final settings = context.read<Settings>();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _QuickSpeedLimitDialog(settings: settings),
  );
}

class _QuickSpeedLimitDialog extends StatefulWidget {
  const _QuickSpeedLimitDialog({required this.settings});

  final Settings settings;

  @override
  State<_QuickSpeedLimitDialog> createState() => _QuickSpeedLimitDialogState();
}

class _QuickSpeedLimitDialogState extends State<_QuickSpeedLimitDialog> {
  late final TextEditingController _downloadController;
  late final TextEditingController _uploadController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _downloadController = TextEditingController(
      text: widget.settings.maxOverallDownloadLimit == 0
          ? ''
          : '${widget.settings.maxOverallDownloadLimit}',
    );
    _uploadController = TextEditingController(
      text: widget.settings.maxOverallUploadLimit == 0
          ? ''
          : '${widget.settings.maxOverallUploadLimit}',
    );
  }

  @override
  void dispose() {
    _downloadController.dispose();
    _uploadController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);

    final download = int.tryParse(_downloadController.text.trim()) ?? 0;
    final upload = int.tryParse(_uploadController.text.trim()) ?? 0;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.settings.setMaxOverallDownloadLimit(download);
      await widget.settings.setMaxOverallUploadLimit(upload);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.saveSettingsFailed)),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    try {
      final applied = await applySpeedLimitsToBuiltin(context);
      if (!applied && BuiltinInstanceService().isRunning()) {
        throw StateError('running built-in instance rejected speed limits');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.saveSettingsFailed)),
        );
      }
      return;
    }
    if (mounted) {
      setState(() => _saving = false);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.speedLimits),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _downloadController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.maxOverallDownloadSpeed,
              suffixText: 'KB/s',
              border: const OutlineInputBorder(),
              helperText: l10n.downloadLimitTip,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _uploadController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.maxOverallUploadSpeed,
              suffixText: 'KB/s',
              border: const OutlineInputBorder(),
              helperText: l10n.uploadLimitTip,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
      ],
    );
  }
}
