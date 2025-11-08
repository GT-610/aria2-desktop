import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../models/settings.dart';
import './components/appearance_dialog.dart';
import '../../utils/logging/log_extensions.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with Loggable {
  String _version = '';
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    initLogger();
    _loadVersionInfo();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      logger.i('Loading settings in settings page');
      await Provider.of<Settings>(context, listen: false).loadSettings();
      logger.i('Settings loaded successfully');
    } catch (e) {
      logger.e('Failed to load settings', error: e);
      _showErrorSnackBar('加载设置失败');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final settings = Provider.of<Settings>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Global settings section
            Text(
              '全局设置',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
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
                        '系统启动时自动运行',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: const Text('设置应用随系统启动而运行'),
                      value: settings.autoStart,
                      onChanged: (value) async {
                        try {
                          await settings.setAutoStart(value);
                          logger.i('Auto-start setting changed to: $value');
                        } catch (e) {
                          logger.e('Failed to save auto-start setting', error: e);
                          _showErrorSnackBar('保存设置失败');
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        '最小化到系统托盘',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: const Text('关闭窗口时最小化到系统托盘而不是退出'),
                      value: settings.minimizeToTray,
                      onChanged: (value) async {
                        try {
                          await settings.setMinimizeToTray(value);
                          logger.i('Minimize to tray setting changed to: $value');
                        } catch (e) {
                          logger.e('Failed to save minimize to tray setting', error: e);
                          _showErrorSnackBar('保存设置失败');
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        '外观',
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: const Text('自定义应用程序的主题和颜色'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 16),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: settings.primaryColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colorScheme.outline),
                            ),
                          ),
                          Text(settings.themeMode.name == 'light' ? '亮色' : 
                               settings.themeMode.name == 'dark' ? '暗色' : '系统'),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: () => _showAppearanceDialog(context, settings),
                    ),
                  ],
                ),
              ),
            ),

            // Log settings section
            Text(
              '日志设置',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
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
                        selected: {settings.logLevelString},
                        onSelectionChanged: (newSelection) async {
                          if (newSelection.isNotEmpty) {
                            final value = newSelection.first;
                            try {
                              final logLevel = LogLevel.values.firstWhere((e) => e.name == value);
                              await settings.setLogLevel(logLevel);
                              logger.i('Log level changed to: $value');
                            } catch (e) {
                              logger.e('Failed to save log level setting', error: e);
                              _showErrorSnackBar('保存设置失败');
                            }
                          }
                        },
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: colorScheme.surfaceContainerHighest,
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
                      value: settings.saveLogsToFile,
                      onChanged: (value) async {
                        try {
                          await settings.setSaveLogsToFile(value);
                          logger.i('Save logs to file setting changed to: $value');
                        } catch (e) {
                          logger.e('Failed to save save logs setting', error: e);
                          _showErrorSnackBar('保存设置失败');
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        onPressed: () async {
                          try {
                            logger.i('Attempting to open log directory');
                            _showInfoSnackBar('此功能将在后续版本中实现');
                          } catch (e) {
                            logger.e('Failed to open log directory', error: e);
                            _showErrorSnackBar('无法打开日志目录');
                          }
                        },
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
            
            // About section
            Text(
              '关于',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
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
  
  // Show appearance settings dialog
  void _showAppearanceDialog(BuildContext context, Settings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return AppearanceDialog(settings: settings);
      },
    );
  }
  
  // 显示错误提示
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  // 显示信息提示
  void _showInfoSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}