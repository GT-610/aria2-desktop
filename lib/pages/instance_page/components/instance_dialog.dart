import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../services/aria2_rpc_client.dart';

class InstanceDialog extends StatefulWidget {
  final Aria2Instance? instance;
  final void Function(Aria2Instance instance)? onSave;

  const InstanceDialog({super.key, this.instance, this.onSave});

  @override
  State<InstanceDialog> createState() => _InstanceDialogState();
}

class _InstanceDialogState extends State<InstanceDialog> {
  static const double _dialogPadding = 24;
  static const double _sectionSpacing = 20;
  static const double _fieldSpacing = 16;

  late String _name;
  late String _protocol;
  late String _host;
  late int _port;
  late String _secret;
  late String _downloadDir;
  late String _rpcPath;
  late String _rpcRequestHeaders;

  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _secretController;
  late final TextEditingController _downloadDirController;
  late final TextEditingController _rpcPathController;
  late final TextEditingController _rpcRequestHeadersController;

  String? _nameError;
  String? _hostError;
  String? _portError;
  bool _showSecret = false;
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();

    if (widget.instance != null) {
      _name = widget.instance!.name;
      _protocol = widget.instance!.protocol;
      _host = widget.instance!.host;
      _port = widget.instance!.port;
      _secret = widget.instance!.secret;
      _downloadDir = widget.instance!.downloadDir;
      _rpcPath = widget.instance!.rpcPath;
      _rpcRequestHeaders = widget.instance!.rpcRequestHeaders;
    } else {
      _name = '';
      _protocol = 'http';
      _host = 'localhost';
      _port = 6800;
      _secret = '';
      _downloadDir = '';
      _rpcPath = 'jsonrpc';
      _rpcRequestHeaders = '';
    }

    _nameController = TextEditingController(text: _name);
    _hostController = TextEditingController(text: _host);
    _portController = TextEditingController(text: _port.toString());
    _secretController = TextEditingController(text: _secret);
    _downloadDirController = TextEditingController(text: _downloadDir);
    _rpcPathController = TextEditingController(text: _rpcPath);
    _rpcRequestHeadersController = TextEditingController(
      text: _rpcRequestHeaders,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    _downloadDirController.dispose();
    _rpcPathController.dispose();
    _rpcRequestHeadersController.dispose();
    super.dispose();
  }

  bool get _usesHttpTransport =>
      _protocol == 'http' || _protocol == 'https';

  String _nameHint(AppLocalizations l10n) {
    final host = _hostController.text.trim().isEmpty
        ? 'localhost'
        : _hostController.text.trim();
    final port = _portController.text.trim().isEmpty
        ? '6800'
        : _portController.text.trim();
    return l10n.instanceNameAutoHint('$host:$port');
  }

  bool _validate({required bool requireName}) {
    final l10n = AppLocalizations.of(context)!;
    final nextName = _nameController.text;
    final nextHost = _hostController.text;
    final nextPortText = _portController.text.trim();
    var isValid = true;
    int? parsedPort;

    if (nextPortText.isNotEmpty) {
      parsedPort = int.tryParse(nextPortText);
    }

    setState(() {
      _name = nextName;
      _host = nextHost;
      _secret = _secretController.text;
      _downloadDir = _downloadDirController.text;
      _rpcPath = _rpcPathController.text;
      _rpcRequestHeaders = _rpcRequestHeadersController.text;

      if (requireName) {
        if (_name.trim().isEmpty) {
          _nameError = l10n.instanceNameRequired;
          isValid = false;
        } else if (_name.trim().length > 30) {
          _nameError = l10n.instanceNameTooLong;
          isValid = false;
        } else {
          _nameError = null;
        }
      } else {
        _nameError = null;
      }

      if (_host.trim().isEmpty) {
        _hostError = l10n.hostRequired;
        isValid = false;
      } else {
        _hostError = null;
      }

      if (nextPortText.isEmpty) {
        _portError = l10n.portRequired;
        isValid = false;
      } else if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
        _portError = l10n.portInvalid;
        isValid = false;
      } else {
        _portError = null;
        _port = parsedPort;
      }
    });

    return isValid;
  }

  Aria2Instance? _buildDraftInstance({required bool requireName}) {
    if (!_validate(requireName: requireName)) {
      return null;
    }

    return Aria2Instance(
      id: widget.instance?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.trim(),
      type: InstanceType.remote,
      protocol: _protocol,
      host: _host.trim(),
      port: _port,
      secret: _secretController.text.trim(),
      downloadDir: _downloadDirController.text.trim(),
      rpcPath: _rpcPathController.text.trim(),
      rpcRequestHeaders: _usesHttpTransport
          ? _rpcRequestHeadersController.text
          : '',
    );
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context)!;
    final draft = _buildDraftInstance(requireName: false);
    if (draft == null) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
    });

    final client = Aria2RpcClient(draft);
    try {
      final reachable = await client.testConnection();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reachable
                ? l10n.instanceReachable
                : l10n.instanceOfflineUnreachable,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.checkStatusFailed('$error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  void _submit() {
    final instance = _buildDraftInstance(requireName: true);
    if (instance == null) {
      return;
    }

    if (widget.onSave != null) {
      widget.onSave!(instance);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else if (mounted) {
      Navigator.of(context).pop(instance);
    }
  }

  Widget _buildSecretField(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return TextField(
      controller: _secretController,
      obscureText: !_showSecret,
      onChanged: (value) => _secret = value,
      decoration: InputDecoration(
        labelText: l10n.rpcSecret,
        hintText: l10n.rpcSecretTip,
        suffixIcon: IconButton(
          onPressed: () {
            setState(() {
              _showSecret = !_showSecret;
            });
          },
          icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
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
      insetPadding: const EdgeInsets.symmetric(
        horizontal: _dialogPadding,
        vertical: _dialogPadding,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.84,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(_dialogPadding).copyWith(
                bottom: _fieldSpacing,
              ),
              child: Text(
                widget.instance == null ? l10n.addInstance : l10n.editInstance,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  _dialogPadding,
                  0,
                  _dialogPadding,
                  8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fl.Input(
                      controller: _nameController,
                      label: l10n.instanceName,
                      hint: _nameHint(l10n),
                      errorText: _nameError,
                      onChanged: (value) {
                        _name = value;
                        if (_nameError != null) {
                          setState(() {
                            _nameError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: _fieldSpacing),
                    Container(
                      padding: const EdgeInsets.all(_fieldSpacing),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.protocol,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'http',
                                label: Text('HTTP'),
                              ),
                              ButtonSegment(
                                value: 'https',
                                label: Text('HTTPS'),
                              ),
                              ButtonSegment(value: 'ws', label: Text('WS')),
                              ButtonSegment(value: 'wss', label: Text('WSS')),
                            ],
                            selected: {_protocol},
                            onSelectionChanged: (newSelection) {
                              if (newSelection.isEmpty) {
                                return;
                              }
                              setState(() {
                                _protocol = newSelection.first;
                              });
                            },
                            style: SegmentedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              backgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: _fieldSpacing),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _hostController,
                                  onChanged: (value) {
                                    _host = value;
                                    if (_hostError != null) {
                                      setState(() {
                                        _hostError = null;
                                      });
                                    } else {
                                      setState(() {});
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: l10n.host,
                                    hintText: 'localhost',
                                    errorText: _hostError,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 112,
                                child: TextField(
                                  controller: _portController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    if (_portError != null) {
                                      setState(() {
                                        _portError = null;
                                      });
                                    } else {
                                      setState(() {});
                                    }
                                    final port = int.tryParse(value);
                                    if (port != null) {
                                      _port = port;
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: l10n.port,
                                    hintText: '6800',
                                    errorText: _portError,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: _fieldSpacing),
                          fl.Input(
                            controller: _rpcPathController,
                            label: l10n.rpcPath,
                            hint: l10n.rpcPathTip,
                            onChanged: (value) {
                              setState(() {
                                _rpcPath = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: _sectionSpacing),
                    _buildSecretField(context, l10n),
                    if (_usesHttpTransport) ...[
                      const SizedBox(height: _fieldSpacing),
                      TextField(
                        controller: _rpcRequestHeadersController,
                        minLines: 4,
                        maxLines: 6,
                        onChanged: (value) => _rpcRequestHeaders = value,
                        decoration: InputDecoration(
                          labelText: l10n.rpcRequestHeaders,
                          hintText: l10n.rpcRequestHeadersTip,
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: _sectionSpacing),
                    fl.Input(
                      controller: _downloadDirController,
                      label: l10n.defaultDownloadDir,
                      hint: l10n.remoteDownloadDirHint,
                      onChanged: (value) => _downloadDir = value,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(_dialogPadding).copyWith(top: 8),
              child: Row(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isTestingConnection ? null : _testConnection,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        icon: _isTestingConnection
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: fl.SizedLoading.small,
                              )
                            : const Icon(Icons.wifi_find_outlined),
                        label: Text(
                          _isTestingConnection
                              ? l10n.testingConnection
                              : l10n.testConnection,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      fl.Btn.cancel(onTap: () => Navigator.of(context).pop()),
                      const SizedBox(width: 8),
                      fl.Btn.elevated(
                        text: widget.instance == null ? l10n.add : l10n.save,
                        onTap: _submit,
                      ),
                    ],
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
