import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../utils/logging.dart';

/// Reusable directory picker component
/// Used to select file save location, supporting both text editing and directory browsing
class DirectoryPicker extends StatefulWidget {
  /// Initial directory path
  final String initialDirectory;
  
  /// Label text
  final String labelText;
  
  /// Hint text
  final String hintText;
  
  /// Dialog title when selecting directory
  final String dialogTitle;
  
  /// Directory path change callback
  final ValueChanged<String> onDirectoryChanged;
  
  /// Directory selection error callback
  final ValueChanged<String>? onError;

  const DirectoryPicker({
    super.key,
    required this.initialDirectory,
    this.labelText = '保存位置',
    this.hintText = '默认下载目录',
    this.dialogTitle = '选择保存位置',
    required this.onDirectoryChanged,
    this.onError,
  });

  @override
  State<DirectoryPicker> createState() => _DirectoryPickerState();
}

class _DirectoryPickerState extends State<DirectoryPicker> with Loggable {
  late TextEditingController _directoryController;

  @override
  void initState() {
    super.initState();
    _directoryController = TextEditingController(text: widget.initialDirectory);
    initLogger();
  }

  @override
  void dispose() {
    _directoryController.dispose();
    super.dispose();
  }

  /// Select save directory
  Future<void> _selectDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: widget.dialogTitle,
        initialDirectory: _directoryController.text.isNotEmpty ? _directoryController.text : null,
      );
      
      if (selectedDirectory != null) {
        _updateDirectory(selectedDirectory);
      }
    } catch (e) {
      logger.e('Failed to select directory', error: e);
      final mountedContext = context;
      if (widget.onError != null) {
        widget.onError!('Failed to select directory: $e');
      } else if (mountedContext.mounted) {
        ScaffoldMessenger.of(mountedContext).showSnackBar(
          SnackBar(content: Text('Failed to select directory: $e')),
        );
      }
    }
  }

  /// Update directory path
  void _updateDirectory(String newDirectory) {
    _directoryController.text = newDirectory;
    widget.onDirectoryChanged(newDirectory);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _directoryController,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              border: const OutlineInputBorder(),
            ),
            onChanged: _updateDirectory,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _selectDirectory,
          child: const Icon(Icons.folder_open),
        ),
      ],
    );
  }
}