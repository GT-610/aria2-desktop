import 'package:flutter/material.dart';
import '../../../models/aria2_instance.dart';

class InstanceDialog extends StatefulWidget {
  final Aria2Instance? instance; // Instance to edit, null for new instance
  final void Function(Aria2Instance instance)? onSave; // Save callback function

  const InstanceDialog({super.key, this.instance, this.onSave});

  @override
  State<InstanceDialog> createState() => _InstanceDialogState();
}

class _InstanceDialogState extends State<InstanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late InstanceType _type;
  late String _protocol;
  late String _host;
  late int _port;
  late String _secret;

  @override
  void initState() {
    super.initState();
    
    // If in edit mode, fill with existing data
    if (widget.instance != null) {
      _name = widget.instance!.name;
      _type = widget.instance!.type;
      _protocol = widget.instance!.protocol;
      _host = widget.instance!.host;
      _port = widget.instance!.port;
      _secret = widget.instance!.secret;
    } else {
      // Default values
      _name = '';
      _type = InstanceType.remote; // Default to remote instance
      _protocol = 'http';
      _host = 'localhost';
      _port = 6800;
      _secret = '';
    }
  }

  // Submit form
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Create or update instance object
    final instance = Aria2Instance(
      id: widget.instance?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name,
      type: _type,
      protocol: _protocol,
      host: _host,
      port: _port,
      secret: _secret,
      aria2Path: null, // No aria2Path needed for remote or built-in instances
    );

    // If callback function is provided, use it
    if (widget.onSave != null) {
      widget.onSave!(instance);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // Otherwise return the result
      if (mounted) {
        Navigator.of(context).pop(instance);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.8; // 设置最大高度为屏幕高度的80%

    return Dialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog title
            Padding(
              padding: const EdgeInsets.all(24).copyWith(bottom: 16),
              child: Text(
                widget.instance == null ? '添加实例' : '编辑实例',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            
            // 可滚动的表单内容
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Instance name
                        TextFormField(
                          initialValue: _name,
                          decoration: InputDecoration(
                            labelText: '实例名称',
                            hintText: '输入实例名称',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入实例名称';
                            }
                            if (value.length > 30) {
                              return '实例名称不能超过30个字符';
                            }
                            return null;
                          },
                          onChanged: (value) => _name = value,
                        ),
                        const SizedBox(height: 16),

                        // Instance type (fixed to remote for new instances)
                        if (widget.instance == null) 
                          Row(
                            children: [
                              Icon(Icons.cloud_outlined, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('远程实例', style: theme.textTheme.bodyLarge),
                            ],
                          )
                        else if (widget.instance!.type == InstanceType.builtin)
                          Row(
                            children: [
                              Icon(Icons.lock, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('内建实例', style: theme.textTheme.bodyLarge),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Icon(Icons.cloud_outlined, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('远程实例', style: theme.textTheme.bodyLarge),
                            ],
                          ),
                        const SizedBox(height: 16),

                        // Protocol selection
                        DropdownButtonFormField<String>(
                          initialValue: _protocol,
                          decoration: InputDecoration(
                            labelText: '协议',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                          ),
                          items: ['http', 'https', 'ws', 'wss'].map((protocol) {
                            return DropdownMenuItem(
                              value: protocol,
                              child: Text(protocol.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _protocol = value!);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Host address
                        TextFormField(
                          initialValue: _host,
                          decoration: InputDecoration(
                            labelText: '主机地址',
                            hintText: 'localhost 或 IP地址 或 域名',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入主机地址';
                            }
                            // Simple IP or domain validation
                            final ipPattern = RegExp(r'^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4}$');
                            final domainPattern = RegExp(r'^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$');
                            if (value != 'localhost' && !ipPattern.hasMatch(value) && !domainPattern.hasMatch(value)) {
                              return '请输入有效的主机地址';
                            }
                            return null;
                          },
                          onChanged: (value) => _host = value,
                        ),
                        const SizedBox(height: 16),

                        // Port
                        TextFormField(
                          initialValue: _port.toString(),
                          decoration: InputDecoration(
                            labelText: '端口',
                            hintText: '6800',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入端口';
                            }
                            final port = int.tryParse(value);
                            if (port == null || port < 1 || port > 65535) {
                              return '请输入有效的端口号 (1-65535)';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              final port = int.tryParse(value);
                              if (port != null) _port = port;
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Secret
                        TextFormField(
                          initialValue: _secret,
                          decoration: InputDecoration(
                            labelText: '密钥 (可选)',
                            hintText: '如果Aria2设置了密钥，请输入',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest,
                            helperText: 'Aria2 RPC密钥，如果设置了的话',
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: colorScheme.primary, width: 2),
                            ),
                          ),
                          onChanged: (value) => _secret = value,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(24).copyWith(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(widget.instance == null ? '添加' : '保存'),
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