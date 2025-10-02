import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 全局设置部分
            const Text(
              '全局设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('启动时自动连接上次使用的实例'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    SwitchListTile(
                      title: const Text('系统启动时自动运行'),
                      value: false,
                      onChanged: (value) {},
                    ),
                    SwitchListTile(
                      title: const Text('最小化到系统托盘'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    ListTile(
                      title: const Text('主题'),
                      trailing: DropdownButton<String>(
                        value: '跟随系统',
                        items: const [
                          DropdownMenuItem(value: '亮色', child: Text('亮色')),
                          DropdownMenuItem(value: '暗色', child: Text('暗色')),
                          DropdownMenuItem(value: '跟随系统', child: Text('跟随系统')),
                        ],
                        onChanged: (value) {},
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 代理设置部分
            const Text(
              '代理设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('启用代理'),
                      value: false,
                      onChanged: (value) {},
                    ),
                    ListTile(
                      title: const Text('代理类型'),
                      trailing: DropdownButton<String>(
                        value: 'HTTP',
                        items: const [
                          DropdownMenuItem(value: 'HTTP', child: Text('HTTP')),
                          DropdownMenuItem(value: 'SOCKS5', child: Text('SOCKS5')),
                        ],
                        onChanged: (value) {},
                      ),
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: '代理地址'),
                      enabled: false,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: '代理端口'),
                      enabled: false,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),

            // 日志设置部分
            const Text(
              '日志设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('日志级别'),
                      trailing: DropdownButton<String>(
                        value: 'Info',
                        items: const [
                          DropdownMenuItem(value: 'Debug', child: Text('Debug')),
                          DropdownMenuItem(value: 'Info', child: Text('Info')),
                          DropdownMenuItem(value: 'Warning', child: Text('Warning')),
                          DropdownMenuItem(value: 'Error', child: Text('Error')),
                        ],
                        onChanged: (value) {},
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('保存日志到文件'),
                      value: true,
                      onChanged: (value) {},
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('查看日志文件'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}