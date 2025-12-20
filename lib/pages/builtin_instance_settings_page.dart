import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';

class BuiltinInstanceSettingsPage extends StatefulWidget {
  const BuiltinInstanceSettingsPage({super.key});

  @override
  State<BuiltinInstanceSettingsPage> createState() => _BuiltinInstanceSettingsPageState();
}

class _BuiltinInstanceSettingsPageState extends State<BuiltinInstanceSettingsPage> {
  // 用于跟踪表单是否有未保存的更改
  bool _hasChanges = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<Settings>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('内建实例设置'),
        actions: [
          TextButton(
            onPressed: _hasChanges
                ? () {
                    // 保存设置
                    _hasChanges = false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('设置已保存'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 连接设置
            _buildSectionTitle('连接设置'),
            Card(
              margin: const EdgeInsets.only(bottom: 24),
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
                    _buildTextFieldSetting(
                      'RPC监听端口',
                      settings.rpcListenPort.toString(),
                      (value) {
                        final port = int.tryParse(value) ?? 6800;
                        settings.setRpcListenPort(port);
                        _hasChanges = true;
                      },
                      keyboardType: TextInputType.number,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildTextFieldSetting(
                      'RPC密钥',
                      settings.rpcSecret,
                      (value) {
                        settings.setRpcSecret(value);
                        _hasChanges = true;
                      },
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),

            // 传输设置
            _buildSectionTitle('传输设置'),
            Card(
              margin: const EdgeInsets.only(bottom: 24),
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
                    _buildNumberSetting(
                      '最大并发下载数',
                      settings.maxConcurrentDownloads,
                      (value) {
                        settings.setMaxConcurrentDownloads(value);
                        _hasChanges = true;
                      },
                      min: 1,
                      max: 16,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNumberSetting(
                      '单服务器最大连接数',
                      settings.maxConnectionPerServer,
                      (value) {
                        settings.setMaxConnectionPerServer(value);
                        _hasChanges = true;
                      },
                      min: 1,
                      max: 128,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNumberSetting(
                      '下载分片数',
                      settings.split,
                      (value) {
                        settings.setSplit(value);
                        _hasChanges = true;
                      },
                      min: 1,
                      max: 128,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSwitchSetting(
                      '允许断点续传',
                      settings.continueDownloads,
                      (value) {
                        settings.setContinueDownloads(value);
                        _hasChanges = true;
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 速度设置
            _buildSectionTitle('速度设置'),
            Card(
              margin: const EdgeInsets.only(bottom: 24),
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
                    _buildNumberSetting(
                      '全局下载限速 (KB/s)',
                      settings.maxOverallDownloadLimit,
                      (value) {
                        settings.setMaxOverallDownloadLimit(value);
                        _hasChanges = true;
                      },
                      min: 0,
                      max: 65535,
                      suffix: '0表示不限速',
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNumberSetting(
                      '全局上传限速 (KB/s)',
                      settings.maxOverallUploadLimit,
                      (value) {
                        settings.setMaxOverallUploadLimit(value);
                        _hasChanges = true;
                      },
                      min: 0,
                      max: 65535,
                      suffix: '0表示不限速',
                    ),
                  ],
                ),
              ),
            ),

            // BT设置
            _buildSectionTitle('BT设置'),
            Card(
              margin: const EdgeInsets.only(bottom: 24),
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
                    _buildSwitchSetting(
                      '保存BT元数据',
                      settings.btSaveMetadata,
                      (value) {
                        settings.setBtSaveMetadata(value);
                        _hasChanges = true;
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSwitchSetting(
                      '加载已保存的BT元数据',
                      settings.btLoadSavedMetadata,
                      (value) {
                        settings.setBtLoadSavedMetadata(value);
                        _hasChanges = true;
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSwitchSetting(
                      '强制BT加密',
                      settings.btForceEncryption,
                      (value) {
                        settings.setBtForceEncryption(value);
                        _hasChanges = true;
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSwitchSetting(
                      '持续做种',
                      settings.keepSeeding,
                      (value) {
                        settings.setKeepSeeding(value);
                        _hasChanges = true;
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNumberSetting(
                      '做种比率',
                      settings.seedRatio.toInt(),
                      (value) {
                        settings.setSeedRatio(value.toDouble());
                        _hasChanges = true;
                      },
                      min: 0,
                      max: 100,
                      suffix: '0表示无限做种',
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNumberSetting(
                      '做种时间 (分钟)',
                      settings.seedTime,
                      (value) {
                        settings.setSeedTime(value);
                        _hasChanges = true;
                      },
                      min: 0,
                      max: 10080, // 7天
                      suffix: '0表示无限做种',
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildTextFieldSetting(
                      '排除的Tracker',
                      settings.btExcludeTracker,
                      (value) {
                        settings.setBtExcludeTracker(value);
                        _hasChanges = true;
                      },
                      helperText: '多个Tracker用逗号分隔',
                    ),
                  ],
                ),
              ),
            ),

            // 高级设置
            _buildSectionTitle('高级设置'),
            Card(
              margin: const EdgeInsets.only(bottom: 24),
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
                    _buildTextFieldSetting(
                      '全局代理',
                      settings.allProxy,
                      (value) {
                        settings.setAllProxy(value);
                        _hasChanges = true;
                      },
                      helperText: '格式: http://proxy:port',
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildTextFieldSetting(
                      '不使用代理的地址',
                      settings.noProxy,
                      (value) {
                        settings.setNoProxy(value);
                        _hasChanges = true;
                      },
                      helperText: '多个地址用逗号分隔',
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildNumberSetting(
                      'DHT监听端口',
                      settings.dhtListenPort,
                      (value) {
                        settings.setDhtListenPort(value);
                        _hasChanges = true;
                      },
                      min: 1024,
                      max: 65535,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSwitchSetting(
                      '启用DHT6',
                      settings.enableDht6,
                      (value) {
                        settings.setEnableDht6(value);
                        _hasChanges = true;
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSwitchSetting(
                      '自动文件重命名',
                      settings.autoFileRenaming,
                      (value) {
                        settings.setAutoFileRenaming(value);
                        _hasChanges = true;
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildSwitchSetting(
                      '允许覆盖文件',
                      settings.allowOverwrite,
                      (value) {
                        settings.setAllowOverwrite(value);
                        _hasChanges = true;
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _buildTextFieldSetting(
                      '用户代理',
                      settings.userAgent,
                      (value) {
                        settings.setUserAgent(value);
                        _hasChanges = true;
                      },
                      maxLines: 1,
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

  // 辅助方法：构建节标题
  Widget _buildSectionTitle(String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // 辅助方法：构建开关设置项
  Widget _buildSwitchSetting(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile.adaptive(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: Theme.of(context).colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }

  // 辅助方法：构建数字输入设置项
  Widget _buildNumberSetting(
    String title,
    int value,
    Function(int) onChanged,
    {int min = 0, int max = 100, String suffix = ''}
  ) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(title),
      subtitle: suffix.isNotEmpty ? Text(suffix) : null,
      trailing: SizedBox(
        width: 100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: () {
                if (value > min) {
                  onChanged(value - 1);
                }
              },
              icon: const Icon(Icons.remove),
              iconSize: 20,
              tooltip: '减少',
            ),
            SizedBox(
              width: 40,
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              onPressed: () {
                if (value < max) {
                  onChanged(value + 1);
                }
              },
              icon: const Icon(Icons.add),
              iconSize: 20,
              tooltip: '增加',
            ),
          ],
        ),
      ),
    );
  }

  // 辅助方法：构建文本输入设置项
  Widget _buildTextFieldSetting(
    String title,
    String initialValue,
    Function(String) onChanged,
    {TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String helperText = '',
    int maxLines = 1}
  ) {
    return ListTile(
      title: Text(title),
      contentPadding: EdgeInsets.zero,
      subtitle: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          decoration: InputDecoration(
            helperText: helperText,
            border: const UnderlineInputBorder(),
            isDense: true,
          ),
        ),
      ),
    );
  }
}