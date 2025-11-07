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
                      value: false,
                      onChanged: (value) {},
                      activeThumbColor: colorScheme.primary,
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
                      value: true,
                      onChanged: (value) {},
                      activeThumbColor: colorScheme.primary,
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
                        selected: {'info'},
                        onSelectionChanged: (newSelection) {},
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
                      value: true,
                      onChanged: (value) {},
                      activeThumbColor: colorScheme.primary,
                      activeTrackColor: colorScheme.primary,
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
}

// Appearance settings dialog
class AppearanceDialog extends StatefulWidget {
  final Settings settings;
  
  const AppearanceDialog({required this.settings, super.key});
  
  @override
  State<AppearanceDialog> createState() => _AppearanceDialogState();
}

class _AppearanceDialogState extends State<AppearanceDialog> {
  // Material You preset colors
  final List<Color> _presetColors = [
    Colors.blue, // Default
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
  ];
  
  // Custom color picker
  Color _selectedColor = Colors.blue;
  String _selectedThemeMode = 'system';
  
  @override
  void initState() {
    super.initState();
    _selectedColor = widget.settings.primaryColor;
    _selectedThemeMode = widget.settings.themeMode.name;
  }
  
  // Get theme mode from string
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
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '外观设置',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Theme mode section
            Text(
              '主题模式',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'light', label: Text('亮色')),
                ButtonSegment(value: 'dark', label: Text('暗色')),
                ButtonSegment(value: 'system', label: Text('系统')),
              ],
              selected: {_selectedThemeMode},
              onSelectionChanged: (newSelection) {
                if (newSelection.isNotEmpty) {
                  setState(() {
                    _selectedThemeMode = newSelection.first;
                  });
                  final themeMode = _getThemeModeFromString(newSelection.first);
                  widget.settings.setThemeMode(themeMode);
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
            const SizedBox(height: 24),
            
            // Theme color section
            Text(
              '主题色',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            
            // Preset colors section
            Text(
              '预设',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: _presetColors.length,
                itemBuilder: (context, index) {
                  final color = _presetColors[index];
                  final isSelected = color == _selectedColor && widget.settings.customColorCode == null;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                      widget.settings.setPrimaryColor(color, isCustom: false);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? colorScheme.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Custom color section
            Text(
              '自定义',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            
            // Custom color picker UI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: colorScheme.outline),
                        ),
                      ),
                      if (widget.settings.customColorCode != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: colorScheme.onSurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // RGB sliders
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildColorSlider(
                        label: 'R',
                        value: ((_selectedColor.r * 255.0).round() & 0xff).toDouble(),
                        onChanged: (value) {
                          final newColor = Color.fromRGBO(
                            value.toInt(),
                            (_selectedColor.g * 255.0).round() & 0xff,
                            (_selectedColor.b * 255.0).round() & 0xff,
                            1.0,
                          );
                          setState(() {
                            _selectedColor = newColor;
                          });
                        },
                        onChangeEnd: (value) {
                          final newColor = Color.fromRGBO(
                            value.toInt(),
                            (_selectedColor.g * 255.0).round() & 0xff,
                            (_selectedColor.b * 255.0).round() & 0xff,
                            1.0,
                          );
                          widget.settings.setPrimaryColor(newColor, isCustom: true);
                        },
                        activeColor: Colors.red,
                      ),
                      _buildColorSlider(
                        label: 'G',
                        value: ((_selectedColor.g * 255.0).round() & 0xff).toDouble(),
                        onChanged: (value) {
                          final newColor = Color.fromRGBO(
                            (_selectedColor.r * 255.0).round() & 0xff,
                            value.toInt(),
                            (_selectedColor.b * 255.0).round() & 0xff,
                            1.0,
                          );
                          setState(() {
                            _selectedColor = newColor;
                          });
                        },
                        onChangeEnd: (value) {
                          final newColor = Color.fromRGBO(
                            (_selectedColor.r * 255.0).round() & 0xff,
                            value.toInt(),
                            (_selectedColor.b * 255.0).round() & 0xff,
                            1.0,
                          );
                          widget.settings.setPrimaryColor(newColor, isCustom: true);
                        },
                        activeColor: Colors.green,
                      ),
                      _buildColorSlider(
                        label: 'B',
                        value: ((_selectedColor.b * 255.0).round() & 0xff).toDouble(),
                        onChanged: (value) {
                          final newColor = Color.fromRGBO(
                            (_selectedColor.r * 255.0).round() & 0xff,
                            (_selectedColor.g * 255.0).round() & 0xff,
                            value.toInt(),
                            1.0,
                          );
                          setState(() {
                            _selectedColor = newColor;
                          });
                        },
                        onChangeEnd: (value) {
                          final newColor = Color.fromRGBO(
                            (_selectedColor.r * 255.0).round() & 0xff,
                            (_selectedColor.g * 255.0).round() & 0xff,
                            value.toInt(),
                            1.0,
                          );
                          widget.settings.setPrimaryColor(newColor, isCustom: true);
                        },
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Color code display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '颜色代码: #${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                  style: theme.textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完成'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Build color slider
  Widget _buildColorSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    required Color activeColor,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(label),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            activeColor: activeColor,
            inactiveColor: Colors.grey.shade300,
            thumbColor: Colors.white,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(value.toInt().toString()),
        ),
      ],
    );
  }
}