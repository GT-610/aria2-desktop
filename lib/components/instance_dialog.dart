import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/aria2_instance.dart';

class InstanceDialog extends StatefulWidget {
  final Aria2Instance? instance; // 编辑时传入的实例

  const InstanceDialog({super.key, this.instance});

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
    
    // 如果是编辑模式，填充现有数据
    if (widget.instance != null) {
      _name = widget.instance!.name;
      _type = widget.instance!.type;
      _protocol = widget.instance!.protocol;
      _host = widget.instance!.host;
      _port = widget.instance!.port;
      _secret = widget.instance!.secret;
      _aria2Path = widget.instance!.aria2Path;
    } else {
      // 默认值
      _name = '';
      _type = InstanceType.local;
      _protocol = 'http';
      _host = 'localhost';
      _port = 6800;
      _secret = '';
      _aria2Path = null;
    }
  }

  // 验证Aria2可执行文件路径
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

      // 在Windows上检查文件扩展名
      if (Platform.isWindows && !_aria2Path!.toLowerCase().endsWith('.exe')) {
        setState(() => _isLocalAria2PathError = true);
        return;
      }

      setState(() => _isLocalAria2PathError = false);
    } catch (_) {
      setState(() => _isLocalAria2PathError = true);
    }
  }

  // 选择Aria2可执行文件
  Future<void> _selectAria2Path() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: Platform.isWindows ? ['exe'] : [],
        dialogTitle: '选择Aria2可执行文件',
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _aria2Path = result.files.first.path!;
        });
        await _validateAria2Path();
      }
    } catch (e) {
      print('选择文件失败: $e');
    }
  }

  // 提交表单
  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // 对于本地实例，验证Aria2路径
    if (_type == InstanceType.local) {
      await _validateAria2Path();
      if (_isLocalAria2PathError) return;
    }

    // 创建或更新实例对象
    final instance = Aria2Instance(
      id: widget.instance?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name,
      type: _type,
      protocol: _protocol,
      host: _host,
      port: _port,
      secret: _secret,
      aria2Path: _type == InstanceType.local ? _aria2Path : null,
      isActive: widget.instance?.isActive ?? false,
    );

    // 返回结果
    Navigator.of(context).pop(instance);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 对话框标题
            Padding(
              padding: const EdgeInsets.all(24).copyWith(bottom: 16),
              child: Text(
                widget.instance == null ? '添加实例' : '编辑实例',
                style: theme.textTheme.headlineMedium,
              ),
            ),

            // 表单内容
            Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 实例名称
                    TextFormField(
                      initialValue: _name,
                      decoration: InputDecoration(
                        labelText: '实例名称',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入实例名称';
                        }
                        return null;
                      },
                      onChanged: (value) => _name = value,
                    ),
                    const SizedBox(height: 16),

                    // 实例类型
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
                          // 切换类型时重置一些默认值
                          if (_type == InstanceType.local) {
                            _host = 'localhost';
                            _aria2Path = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // 协议选择
                    DropdownButtonFormField<String>(
                      value: _protocol,
                      decoration: InputDecoration(
                        labelText: '协议',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant,
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

                    // 主机地址
                    TextFormField(
                      initialValue: _host,
                      decoration: InputDecoration(
                        labelText: '主机地址',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入主机地址';
                        }
                        return null;
                      },
                      onChanged: (value) => _host = value,
                    ),
                    const SizedBox(height: 16),

                    // 端口
                    TextFormField(
                      initialValue: _port.toString(),
                      decoration: InputDecoration(
                        labelText: '端口',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant,
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

                    // 密钥
                    TextFormField(
                      initialValue: _secret,
                      decoration: InputDecoration(
                        labelText: '密钥 (可选)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant,
                        helperText: 'Aria2 RPC密钥，如果设置了的话',
                      ),
                      onChanged: (value) => _secret = value,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 16),

                    // 本地实例的Aria2路径
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
                                    fillColor: colorScheme.surfaceVariant,
                                    errorText: _isLocalAria2PathError
                                        ? '请选择有效的Aria2可执行文件'
                                        : null,
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
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // 操作按钮
            Padding(
              padding: const EdgeInsets.all(24).copyWith(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
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