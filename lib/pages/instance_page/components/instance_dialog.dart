import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  String? _aria2Path;
  bool _isLocalAria2PathError = false;

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
      _aria2Path = widget.instance!.aria2Path;
    } else {
      // Default values
      _name = '';
      _type = InstanceType.local;
      _protocol = 'http';
      _host = 'localhost';
      _port = 6800;
      _secret = '';
      _aria2Path = null;
    }
  }

  // Validate Aria2 executable path
  Future<void> _validateAria2Path() async {
    if (_aria2Path == null || _aria2Path!.isEmpty) {
      setState(() => _isLocalAria2PathError = true);
      return;
    }

    try {
      final file = File(_aria2Path!);
      final exists = await file.exists();
      
      if (!exists) {
        setState(() => _isLocalAria2PathError = true);
        return;
      }

      // Check file extension on Windows
      if (Platform.isWindows && !_aria2Path!.toLowerCase().endsWith('.exe')) {
        setState(() => _isLocalAria2PathError = true);
        return;
      }

      setState(() => _isLocalAria2PathError = false);
    } catch (_) {
      setState(() => _isLocalAria2PathError = true);
    }
  }

  // Select Aria2 executable file
  Future<void> _selectAria2Path() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: Platform.isWindows ? ['exe'] : [],
        dialogTitle: '选择Aria2可执行文件',
      );

      if (result != null && result.files.isNotEmpty) {
        if (mounted) {
          setState(() {
            _aria2Path = result.files.first.path!;
          });
          await _validateAria2Path();
        }
      }
    } catch (e) {
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  // Submit form
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // For local instances, validate Aria2 path
    if (_type == InstanceType.local) {
      await _validateAria2Path();
      if (_isLocalAria2PathError) return;
    }

    // Create or update instance object
    final instance = Aria2Instance(
      id: widget.instance?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name,
      type: _type,
      protocol: _protocol,
      host: _host,
      port: _port,
      secret: _secret,
      aria2Path: _type == InstanceType.local ? _aria2Path : null,
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

                        // Instance type
                        SegmentedButton<InstanceType>(
                          segments: const [
                            ButtonSegment(
                              value: InstanceType.local,
                              label: Text('本地实例'),
                              icon: Icon(Icons.computer),
                            ),
                            ButtonSegment(
                              value: InstanceType.remote,
                              label: Text('远程实例'),
                              icon: Icon(Icons.cloud_outlined),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (newSelection) {
                            setState(() {
                              _type = newSelection.first;
                              // Reset some default values when switching types
                              if (_type == InstanceType.local) {
                                _host = 'localhost';
                                _aria2Path = null;
                              }
                            });
                          },
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

                        // Aria2 path for local instance
                        if (_type == InstanceType.local)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aria2 可执行文件路径',
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _aria2Path,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: colorScheme.surfaceContainerHighest,
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                        ),
                                        errorText: _isLocalAria2PathError
                                            ? '请选择有效的Aria2可执行文件'
                                            : null,
                                        helperText: _aria2Path == null || _aria2Path!.isEmpty ? '请点击浏览选择aria2c.exe' : null,
                                      ),
                                      readOnly: true,
                                      onTap: _selectAria2Path,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: _selectAria2Path,
                                    icon: const Icon(Icons.file_open),
                                    label: const Text('浏览'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Card(
                                elevation: 0,
                                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '本地实例需要安装Aria2。请确保aria2c.exe可执行文件正确无误。',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
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