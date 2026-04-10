import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../utils/logging.dart';

/// Reusable directory picker component.
/// Used to select a save location with both text editing and browsing.
class DirectoryPicker extends StatefulWidget {
  final String initialDirectory;
  final String labelText;
  final String hintText;
  final String dialogTitle;
  final ValueChanged<String> onDirectoryChanged;
  final ValueChanged<String>? onError;

  const DirectoryPicker({
    super.key,
    required this.initialDirectory,
    this.labelText = 'Save location',
    this.hintText = 'Use the instance default directory',
    this.dialogTitle = 'Choose save location',
    required this.onDirectoryChanged,
    this.onError,
  });

  @override
  State<DirectoryPicker> createState() => _DirectoryPickerState();
}

class _DirectoryPickerState extends State<DirectoryPicker> with Loggable {
  late final TextEditingController _directoryController;

  @override
  void initState() {
    super.initState();
    _directoryController = TextEditingController(text: widget.initialDirectory);
  }

  @override
  void dispose() {
    _directoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDirectory() async {
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: widget.dialogTitle,
        initialDirectory: _directoryController.text.isNotEmpty
            ? _directoryController.text
            : null,
      );

      if (selectedDirectory != null) {
        _updateDirectory(selectedDirectory);
      }
    } catch (err) {
      this.e('Failed to select directory', error: err);
      if (widget.onError != null) {
        widget.onError!('Failed to select directory: $err');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select directory: $err')),
        );
      }
    }
  }

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
