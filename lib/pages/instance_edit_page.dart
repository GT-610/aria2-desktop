import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/aria2_instance.dart';
import '../services/instance_manager.dart';

class InstanceEditPage extends StatefulWidget {
  final Aria2Instance? instance;
  final InstanceManager instanceManager;

  const InstanceEditPage({
    Key? key,
    this.instance,
    required this.instanceManager,
  }) : super(key: key);

  @override
  State<InstanceEditPage> createState() => _InstanceEditPageState();
}

class _InstanceEditPageState extends State<InstanceEditPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late InstanceType _type;
  late String _protocol;
  late String _host;
  late int _port;
  late String _secret;
  late String? _aria2Path;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.instance != null) {
      // 编辑模式
      _name = widget.instance!.name;
      _type = widget.instance!.type;
      _protocol = widget.instance!.protocol;
      _host = widget.instance!.host;
      _port = widget.instance!.port;
      _secret = widget.instance!.secret;
      _aria2Path = widget.instance!.aria2Path;
    } else {
      // 新增模式
      _name = '';
      _type = InstanceType.local;
      _protocol = 'http';
      _host = 'localhost';
      _port = 6800;
      _secret = '';
      _aria2Path = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.instance != null ? '编辑实例' : '添加实例'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(labelText: '实例名称'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入实例名称';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!,
              ),
              SizedBox(height: 16),
              
              // 实例类型选择
              ListTile(
                title: Text('实例类型'),
                trailing: DropdownButton<InstanceType>(
                  value: _type,
                  items: [
                    DropdownMenuItem(
                      value: InstanceType.local,
                      child: Text('本地'),
                    ),
                    DropdownMenuItem(
                      value: InstanceType.remote,
                      child: Text('远程'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _type = value!;
                    });
                  },
                ),
              ),
              SizedBox(height: 16),
              
              // 协议选择
              ListTile(
                title: Text('协议'),
                trailing: DropdownButton<String>(
                  value: _protocol,
                  items: ['http', 'https', 'ws', 'wss'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (value) {
                    setState(() {
                      _protocol = value!;
                    });
                  },
                ),
              ),
              SizedBox(height: 16),
              
              TextFormField(
                initialValue: _host,
                decoration: InputDecoration(labelText: '主机地址'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入主机地址';
                  }
                  return null;
                },
                onSaved: (value) => _host = value!,
              ),
              SizedBox(height: 16),
              
              TextFormField(
                initialValue: _port.toString(),
                decoration: InputDecoration(labelText: '端口'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入端口';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return '请输入有效的端口号';
                  }
                  return null;
                },
                onSaved: (value) => _port = int.parse(value!),
              ),
              SizedBox(height: 16),
              
              TextFormField(
                initialValue: _secret,
                decoration: InputDecoration(labelText: '密钥（可选）'),
                onSaved: (value) => _secret = value!,
              ),
              SizedBox(height: 16),
              
              // 本地实例才显示的选项
              if (_type == InstanceType.local)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _pickAria2Path,
                      child: Text('选择Aria2可执行文件'),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _aria2Path ?? '未选择文件',
                      style: TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              
              SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('取消'),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveInstance,
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 选择Aria2可执行文件
  Future<void> _pickAria2Path() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _aria2Path = result.files.single.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件失败: $e')),
      );
    }
  }

  /// 保存实例
  Future<void> _saveInstance() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    _formKey.currentState!.save();
    
    setState(() {
      _isLoading = true;
    });

    try {
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

      // 测试连接
      final isConnected = await widget.instanceManager.checkConnection(instance);
      if (!isConnected && _type == InstanceType.remote) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法连接到远程实例，请检查配置')),
        );
        return;
      }

      if (widget.instance != null) {
        await widget.instanceManager.updateInstance(instance);
      } else {
        await widget.instanceManager.addInstance(instance);
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}