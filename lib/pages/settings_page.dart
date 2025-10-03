import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';
  
  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }
  
  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<Settings>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 全局设置部分 - Material You 风格
            Text(
              '全局设置',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              surfaceTintColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: Text(
                        '启动时自动连接上次使用的实例',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: const Text('自动连接到最近使用的Aria2实例'),
                      value: settings.autoConnectLastInstance,
                      onChanged: (value) {
                        settings.setAutoConnectLastInstance(value);
                      },
                      activeColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        '系统启动时自动运行',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: const Text('设置应用随系统启动而运行'),
                      value: false,
                      onChanged: (value) {},
                      activeColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        '最小化到系统托盘',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: const Text('关闭窗口时最小化到系统托盘而不是退出'),
                      value: true,
                      onChanged: (value) {},
                      activeColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        '主题',
                        style: theme.textTheme.bodyLarge,
                      ),
                      trailing: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'light', label: Text('亮色')),
                          ButtonSegment(value: 'dark', label: Text('暗色')),
                          ButtonSegment(value: 'system', label: Text('系统')),
                        ],
                        selected: {settings.themeMode.name},
                        onSelectionChanged: (newSelection) {
                          if (newSelection.isNotEmpty) {
                            final themeMode = _getThemeModeFromString(newSelection.first);
                            settings.setThemeMode(themeMode);
                          }
                        },
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: colorScheme.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                  ],
                ),
              ),
            ),

            // 日志设置部分 - Material You 风格
            Text(
              '日志设置',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              surfaceTintColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        '日志级别',
                        style: theme.textTheme.bodyLarge,
                      ),
                      trailing: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'debug', label: Text('Debug')),
                          ButtonSegment(value: 'info', label: Text('Info')),
                          ButtonSegment(value: 'warning', label: Text('Warning')),
                          ButtonSegment(value: 'error', label: Text('Error')),
                        ],
                        selected: {'info'},
                        onSelectionChanged: (newSelection) {},
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: colorScheme.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        '保存日志到文件',
                        style: theme.textTheme.bodyLarge,
                      ),
                      value: true,
                      onChanged: (value) {},
                      activeColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.file_open),
                        label: const Text('查看日志文件'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 关于部分 - Material You 风格
            Text(
              '关于',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              surfaceTintColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        '版本号',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(_version.isEmpty ? '加载中...' : _version),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        '贡献者',
                        style: theme.textTheme.bodyLarge,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        '许可协议',
                        style: theme.textTheme.bodyLarge,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: () {},
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
  
  // 根据字符串获取主题模式
  ThemeMode _getThemeModeFromString(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}