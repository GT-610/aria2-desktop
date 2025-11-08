import 'package:flutter/material.dart';
import '../../../models/settings.dart';

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