import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';

class InstanceDialog extends StatefulWidget {
  final Aria2Instance? instance;
  final void Function(Aria2Instance instance)? onSave;

  const InstanceDialog({super.key, this.instance, this.onSave});

  @override
  State<InstanceDialog> createState() => _InstanceDialogState();
}

class _InstanceDialogState extends State<InstanceDialog> {
  late String _name;
  late InstanceType _type;
  late String _protocol;
  late String _host;
  late int _port;
  late String _secret;
  late String _downloadDir;

  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _secretController;
  late final TextEditingController _downloadDirController;

  String? _nameError;
  String? _hostError;
  String? _portError;

  @override
  void initState() {
    super.initState();

    if (widget.instance != null) {
      _name = widget.instance!.name;
      _type = widget.instance!.type;
      _protocol = widget.instance!.protocol;
      _host = widget.instance!.host;
      _port = widget.instance!.port;
      _secret = widget.instance!.secret;
      _downloadDir = widget.instance!.downloadDir;
    } else {
      _name = '';
      _type = InstanceType.remote;
      _protocol = 'http';
      _host = 'localhost';
      _port = 6800;
      _secret = '';
      _downloadDir = '';
    }

    _nameController = TextEditingController(text: _name);
    _hostController = TextEditingController(text: _host);
    _portController = TextEditingController(text: _port.toString());
    _secretController = TextEditingController(text: _secret);
    _downloadDirController = TextEditingController(text: _downloadDir);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    _downloadDirController.dispose();
    super.dispose();
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context)!;
    bool isValid = true;

    setState(() {
      if (_name.trim().isEmpty) {
        _nameError = l10n.instanceNameRequired;
        isValid = false;
      } else if (_name.trim().length > 30) {
        _nameError = l10n.instanceNameTooLong;
        isValid = false;
      } else {
        _nameError = null;
      }

      if (_host.trim().isEmpty) {
        _hostError = l10n.hostRequired;
        isValid = false;
      } else {
        _hostError = null;
      }

      if (_portController.text.trim().isEmpty) {
        _portError = l10n.portRequired;
        isValid = false;
      } else {
        final portNum = int.tryParse(_portController.text.trim());
        if (portNum == null || portNum < 1 || portNum > 65535) {
          _portError = l10n.portInvalid;
          isValid = false;
        } else {
          _portError = null;
          _port = portNum;
        }
      }
    });

    return isValid;
  }

  void _submit() {
    if (!_validate()) return;

    final instance = Aria2Instance(
      id:
          widget.instance?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.trim(),
      type: _type,
      protocol: _protocol,
      host: _host.trim(),
      port: _port,
      secret: _secret,
      downloadDir: _downloadDir.trim(),
    );

    if (widget.onSave != null) {
      widget.onSave!(instance);
      if (mounted) Navigator.of(context).pop();
    } else {
      if (mounted) Navigator.of(context).pop(instance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24).copyWith(bottom: 16),
              child: Text(
                widget.instance == null ? l10n.addInstance : l10n.editInstance,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Input(
                      controller: _nameController,
                      label: l10n.instanceName,
                      hint: l10n.instanceNameTip,
                      errorText: _nameError,
                      onChanged: (value) {
                        _name = value;
                        if (_nameError != null) {
                          setState(() => _nameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.cloud_outlined, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          _type == InstanceType.builtin
                              ? l10n.builtin
                              : l10n.remote,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _protocol,
                      decoration: InputDecoration(labelText: l10n.protocol),
                      items: ['http', 'https', 'ws', 'wss'].map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text(p.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _protocol = value!),
                    ),
                    const SizedBox(height: 16),
                    Input(
                      controller: _hostController,
                      label: l10n.host,
                      hint: l10n.hostTip,
                      errorText: _hostError,
                      onChanged: (value) {
                        _host = value;
                        if (_hostError != null) {
                          setState(() => _hostError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Input(
                      controller: _portController,
                      label: l10n.port,
                      hint: '6800',
                      type: TextInputType.number,
                      errorText: _portError,
                      onChanged: (value) {
                        if (_portError != null) {
                          setState(() => _portError = null);
                        }
                        final port = int.tryParse(value);
                        if (port != null) _port = port;
                      },
                    ),
                    const SizedBox(height: 16),
                    Input(
                      controller: _secretController,
                      label: l10n.rpcSecret,
                      hint: l10n.rpcSecretTip,
                      obscureText: true,
                      onChanged: (value) => _secret = value,
                    ),
                    const SizedBox(height: 16),
                    Input(
                      controller: _downloadDirController,
                      label: l10n.defaultDownloadDir,
                      hint: l10n.remoteDownloadDirHint,
                      onChanged: (value) => _downloadDir = value,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24).copyWith(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Btn.cancel(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 8),
                  Btn.elevated(
                    text: widget.instance == null ? l10n.add : l10n.save,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
