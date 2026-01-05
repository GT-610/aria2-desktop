import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';
import '../services/builtin_instance_service.dart';

class BuiltinInstanceSettingsPage extends StatefulWidget {
  const BuiltinInstanceSettingsPage({super.key});

  @override
  State<BuiltinInstanceSettingsPage> createState() => _BuiltinInstanceSettingsPageState();
}

class _BuiltinInstanceSettingsPageState extends State<BuiltinInstanceSettingsPage> {
  // 用于跟踪表单是否有未保存的更改
  bool _hasChanges = false;
  bool _isSaving = false;
  final BuiltinInstanceService _builtinInstanceService = BuiltinInstanceService();

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<Settings>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('内建实例设置'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _showBackConfirmationDialog(context, settings);
          },
        ),
        actions: [
          TextButton(
            onPressed: _hasChanges
                ? () async {
                    await _saveSettings(settings);
                  }
                : null,
            child: Text(
              '保存',
              style: TextStyle(
                color: _hasChanges ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: _hasChanges
                ? () async {
                    await _saveAndApplySettings(settings);
                  }
                : null,
            child: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onSurface,
                    ),
                  )
                : Text(
                    '保存并应用',
                    style: TextStyle(
                      color: _hasChanges ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基础设置
            _buildSectionHeader('基础设置', theme),
            _buildCard(
              children: [
                _buildTextFieldSetting(
                  'RPC监听端口',
                  settings.rpcListenPort.toString(),
                  (value) {
                    final port = int.tryParse(value) ?? 16800;
                    settings.setRpcListenPort(port);
                    _hasChanges = true;
                  },
                  keyboardType: TextInputType.number,
                  helperText: '默认端口：16800',
                ),
                _buildTextFieldSetting(
                  'RPC密钥',
                  settings.rpcSecret,
                  (value) {
                    settings.setRpcSecret(value);
                    _hasChanges = true;
                  },
                  obscureText: true,
                  helperText: '留空则不需要密钥',
                ),
              ],
              theme: theme,
            ),

            // 传输设置
            _buildSectionHeader('传输设置', theme),
            _buildCard(
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
                _buildSwitchSetting(
                  '允许断点续传',
                  settings.continueDownloads,
                  (value) {
                    settings.setContinueDownloads(value);
                    _hasChanges = true;
                  },
                ),
              ],
              theme: theme,
            ),

            // 速度限制
            _buildSectionHeader('速度限制', theme),
            _buildCard(
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
              theme: theme,
            ),

            // BT/PT 设置
            _buildSectionHeader('BT/PT 设置', theme),
            _buildCard(
              children: [
                _buildSwitchSetting(
                  '保存BT元数据',
                  settings.btSaveMetadata,
                  (value) {
                    settings.setBtSaveMetadata(value);
                    _hasChanges = true;
                  },
                ),
                _buildSwitchSetting(
                  '加载已保存的BT元数据',
                  settings.btLoadSavedMetadata,
                  (value) {
                    settings.setBtLoadSavedMetadata(value);
                    _hasChanges = true;
                  },
                ),
                _buildSwitchSetting(
                  '强制BT加密',
                  settings.btForceEncryption,
                  (value) {
                    settings.setBtForceEncryption(value);
                    _hasChanges = true;
                  },
                ),
                _buildSwitchSetting(
                  '持续做种',
                  settings.keepSeeding,
                  (value) {
                    settings.setKeepSeeding(value);
                    _hasChanges = true;
                  },
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: settings.keepSeeding
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: const SizedBox(height: 0),
                  secondChild: Column(
                    children: [
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
                    ],
                  ),
                ),
                _buildTextFieldSetting(
                  '排除的Tracker',
                  settings.btExcludeTracker,
                  (value) {
                    settings.setBtExcludeTracker(value);
                    _hasChanges = true;
                  },
                  helperText: '多个Tracker用逗号分隔',
                  maxLines: 2,
                ),
              ],
              theme: theme,
            ),

            // 网络设置
            _buildSectionHeader('网络设置', theme),
            _buildCard(
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
                _buildTextFieldSetting(
                  '不使用代理的地址',
                  settings.noProxy,
                  (value) {
                    settings.setNoProxy(value);
                    _hasChanges = true;
                  },
                  helperText: '多个地址用逗号分隔',
                ),
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
                _buildSwitchSetting(
                  '启用DHT6',
                  settings.enableDht6,
                  (value) {
                    settings.setEnableDht6(value);
                    _hasChanges = true;
                  },
                ),
              ],
              theme: theme,
            ),

            // 文件设置
            _buildSectionHeader('文件设置', theme),
            _buildCard(
              children: [
                _buildSwitchSetting(
                  '自动文件重命名',
                  settings.autoFileRenaming,
                  (value) {
                    settings.setAutoFileRenaming(value);
                    _hasChanges = true;
                  },
                ),
                _buildSwitchSetting(
                  '允许覆盖文件',
                  settings.allowOverwrite,
                  (value) {
                    settings.setAllowOverwrite(value);
                    _hasChanges = true;
                  },
                ),
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
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  // 构建节标题
  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  // 构建卡片容器
  Widget _buildCard({required List<Widget> children, required ThemeData theme}) {
    final colorScheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map((entry) => Column(
                  children: [
                    entry.value,
                    if (entry.key < children.length - 1)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: colorScheme.outlineVariant,
                      ),
                  ],
                ))
            .toList(),
      ),
    );
  }

  // 构建开关设置项
  Widget _buildSwitchSetting(String title, bool value, Function(bool) onChanged) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SwitchListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyMedium,
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: colorScheme.primary,
      activeTrackColor: colorScheme.primary.withValues(alpha: 0.3),
      inactiveThumbColor: colorScheme.onSurfaceVariant,
      inactiveTrackColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  // 构建数字输入设置项
  Widget _buildNumberSetting(
    String title,
    int value,
    Function(int) onChanged,
    {int min = 0, int max = 100, String suffix = ''}
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: suffix.isNotEmpty
          ? Text(
              suffix,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      trailing: SizedBox(
        width: 120,
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
              color: value > min 
                  ? colorScheme.onSurface 
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              splashRadius: 20,
            ),
            Container(
              width: 50,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
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
              color: value < max 
                  ? colorScheme.onSurface 
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              splashRadius: 20,
            ),
          ],
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  // 构建文本输入设置项
  Widget _buildTextFieldSetting(
    String title,
    String initialValue,
    Function(String) onChanged,
    {TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String helperText = '',
    int maxLines = 1}
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      title: Text(
        title,
        style: theme.textTheme.bodyMedium,
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      subtitle: Padding(
        padding: const EdgeInsets.only(right: 0),
        child: TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          cursorColor: colorScheme.primary,
          decoration: InputDecoration(
            helperText: helperText,
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          style: theme.textTheme.bodyMedium,
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
    );
  }

  // 保存设置
  Future<void> _saveSettings(Settings settings) async {
    setState(() {
      _isSaving = true;
    });
    
    // 保存设置到本地
    await settings.saveAllSettings();
    
    setState(() {
      _hasChanges = false;
      _isSaving = false;
    });
    
    // 使用当前State对象的mounted属性来检查组件是否仍然挂载
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 保存并应用设置（重启内建实例）
  Future<void> _saveAndApplySettings(Settings settings) async {
    setState(() {
      _isSaving = true;
    });
    
    // 保存设置到本地
    await settings.saveAllSettings();
    
    // 显示等待对话框
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('内建实例正在重启，请稍候...')),
            ],
          ),
        ),
      );
    }
    
    try {
      // 重启内建实例
      await _builtinInstanceService.stopInstance();
      await Future.delayed(const Duration(milliseconds: 500)); // 等待进程完全退出
      final success = await _builtinInstanceService.startInstance();
      
      if (mounted) {
        Navigator.pop(context); // 关闭等待对话框
        
        if (success) {
          setState(() {
            _hasChanges = false;
            _isSaving = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('设置已保存并应用'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() {
            _isSaving = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('设置保存成功，但内建实例重启失败'),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭等待对话框
        
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置保存成功，但内建实例重启时发生错误：$e'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 显示返回确认对话框
  void _showBackConfirmationDialog(BuildContext context, Settings settings) {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认离开'),
        content: const Text('您有未保存的设置，确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 关闭对话框
              await _saveAndApplySettings(settings);
              if (mounted) {
                Navigator.pop(this.context); // 返回上一页
              }
            },
            child: const Text('保存并应用'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 关闭对话框
              await _saveSettings(settings);
              if (mounted) {
                Navigator.pop(this.context); // 返回上一页
              }
            },
            child: const Text('保存'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 关闭对话框
              Navigator.pop(this.context); // 返回上一页
            },
            child: const Text('不保存'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 关闭对话框
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}