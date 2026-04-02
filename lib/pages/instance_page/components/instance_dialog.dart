import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
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

  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _secretController;

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
    } else {
      _name = '';
      _type = InstanceType.remote;
      _protocol = 'http';
      _host = 'localhost';
      _port = 6800;
      _secret = '';
    }

    _nameController = TextEditingController(text: _name);
    _hostController = TextEditingController(text: _host);
    _portController = TextEditingController(text: _port.toString());
    _secretController = TextEditingController(text: _secret);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _submit() {
    final instance = Aria2Instance(
      id:
          widget.instance?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name,
      type: _type,
      protocol: _protocol,
      host: _host,
      port: _port,
      secret: _secret,
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
                widget.instance == null ? '添加实例' : '编辑实例',
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
                      label: '实例名称',
                      hint: '输入实例名称',
                      onChanged: (value) => _name = value,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.cloud_outlined, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          _type == InstanceType.builtin ? '内建实例' : '远程实例',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _protocol,
                      decoration: const InputDecoration(labelText: '协议'),
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
                      label: '主机地址',
                      hint: 'localhost 或 IP地址 或 域名',
                      onChanged: (value) => _host = value,
                    ),
                    const SizedBox(height: 16),
                    Input(
                      controller: _portController,
                      label: '端口',
                      hint: '6800',
                      type: TextInputType.number,
                      onChanged: (value) {
                        final port = int.tryParse(value);
                        if (port != null) _port = port;
                      },
                    ),
                    const SizedBox(height: 16),
                    Input(
                      controller: _secretController,
                      label: '密钥 (可选)',
                      hint: '如果Aria2设置了密钥，请输入',
                      obscureText: true,
                      onChanged: (value) => _secret = value,
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
                    text: widget.instance == null ? '添加' : '保存',
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
