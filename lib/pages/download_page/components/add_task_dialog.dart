import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../utils/logging.dart';
import 'directory_picker.dart';

class AddTaskDialog extends StatefulWidget {
  final List<Aria2Instance> targetInstances;
  final String? defaultTargetInstanceId;
  final Future<void> Function(
    String taskType,
    String uri,
    String downloadDir,
    String? fileContent,
    String targetInstanceId,
  )
  onAddTask;

  const AddTaskDialog({
    super.key,
    required this.targetInstances,
    required this.defaultTargetInstanceId,
    required this.onAddTask,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> with Loggable {
  String saveLocation = '';
  final TextEditingController uriController = TextEditingController();
  bool showAdvancedOptions = false;
  String? selectedTorrentFilePath;
  String? selectedMetalinkFilePath;
  late String? _selectedTargetInstanceId;

  @override
  void initState() {
    super.initState();
    _selectedTargetInstanceId =
        widget.defaultTargetInstanceId ??
        (widget.targetInstances.isNotEmpty
            ? widget.targetInstances.first.id
            : null);
    i('AddTaskDialog initialized');
  }

  @override
  void dispose() {
    uriController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        uriController.text = data!.text!;
        setState(() {});
      }
    } catch (e) {
      this.e('Failed to paste', error: e);
    }
  }

  Future<void> _selectTorrentFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['torrent'],
        dialogTitle: 'Select torrent file',
      );

      if (result != null) {
        setState(() {
          selectedTorrentFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      this.e('Failed to select torrent file', error: e);
    }
  }

  Future<void> _selectMetalinkFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['metalink'],
        dialogTitle: 'Select metalink file',
      );

      if (result != null) {
        setState(() {
          selectedMetalinkFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      this.e('Failed to select Metalink file', error: e);
    }
  }

  Future<void> _submitTask(String taskType) async {
    final l10n = AppLocalizations.of(context)!;
    final targetInstanceId = _selectedTargetInstanceId;
    if (targetInstanceId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.selectTargetInstanceFirst)));
      }
      return;
    }

    final downloadDir = saveLocation;
    final uri = uriController.text;
    String? fileContent;

    if (taskType == 'torrent' && selectedTorrentFilePath != null) {
      final file = File(selectedTorrentFilePath!);
      fileContent = base64Encode(await file.readAsBytes());
    } else if (taskType == 'metalink' && selectedMetalinkFilePath != null) {
      final file = File(selectedMetalinkFilePath!);
      fileContent = base64Encode(await file.readAsBytes());
    }

    await widget.onAddTask(
      taskType,
      uri,
      downloadDir,
      fileContent,
      targetInstanceId,
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  bool get _hasAvailableTargets => widget.targetInstances.isNotEmpty;

  String? _selectedTargetLabel() {
    final l10n = AppLocalizations.of(context)!;
    final selectedId = _selectedTargetInstanceId;
    if (selectedId == null) return null;

    Aria2Instance? selectedInstance;
    for (final instance in widget.targetInstances) {
      if (instance.id == selectedId) {
        selectedInstance = instance;
        break;
      }
    }

    if (selectedInstance == null) return null;

    return selectedInstance.type == InstanceType.builtin
        ? l10n.builtInDefaultInstance(selectedInstance.name)
        : selectedInstance.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: AlertDialog(
        title: Text(l10n.addTaskDialogTitle),
        content: SizedBox(
          width: 520,
          height: 500,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: l10n.uriTab),
                  Tab(text: l10n.torrentTab),
                  Tab(text: l10n.metalinkTab),
                ],
                indicatorSize: TabBarIndicatorSize.tab,
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Input(
                                  controller: uriController,
                                  label: l10n.urlOrMagnetLink,
                                  hint: l10n.enterOneOrMoreLinks,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 8),
                                Btn.tile(
                                  text: l10n.pasteFromClipboard,
                                  icon: const Icon(Icons.paste),
                                  onTap: _pasteFromClipboard,
                                ),
                                const SizedBox(height: 16),
                                Text(l10n.uriSupportHint),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.file_open, size: 64),
                                const SizedBox(height: 16),
                                Btn.tile(
                                  text: l10n.selectTorrentFile,
                                  icon: const Icon(Icons.upload_file),
                                  onTap: _selectTorrentFile,
                                ),
                                const SizedBox(height: 16),
                                if (selectedTorrentFilePath != null)
                                  Text(
                                    l10n.selectedFile(
                                      selectedTorrentFilePath!
                                          .split(Platform.pathSeparator)
                                          .last,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.file_open, size: 64),
                                const SizedBox(height: 16),
                                Btn.tile(
                                  text: l10n.selectMetalinkFile,
                                  icon: const Icon(Icons.upload_file),
                                  onTap: _selectMetalinkFile,
                                ),
                                const SizedBox(height: 16),
                                if (selectedMetalinkFilePath != null)
                                  Text(
                                    l10n.selectedFile(
                                      selectedMetalinkFilePath!
                                          .split(Platform.pathSeparator)
                                          .last,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_hasAvailableTargets) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(l10n.noConnectedInstancesAvailable),
                            ),
                            const SizedBox(height: 12),
                          ] else if (_selectedTargetLabel() != null) ...[
                            Text(
                              l10n.tasksWillBeSentTo(_selectedTargetLabel()!),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                          ],
                          DropdownButtonFormField<String>(
                            initialValue: _selectedTargetInstanceId,
                            decoration: InputDecoration(
                              labelText: l10n.targetInstance,
                            ),
                            items: widget.targetInstances.map((instance) {
                              final label =
                                  instance.type == InstanceType.builtin
                                  ? l10n.builtInInstance(instance.name)
                                  : instance.name;
                              return DropdownMenuItem(
                                value: instance.id,
                                child: Text(label),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedTargetInstanceId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          DirectoryPicker(
                            initialDirectory: saveLocation,
                            onDirectoryChanged: (newLocation) {
                              setState(() {
                                saveLocation = newLocation;
                              });
                            },
                            onError: (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.showAdvancedOptions),
                              Switch(
                                value: showAdvancedOptions,
                                onChanged: (value) {
                                  setState(() {
                                    showAdvancedOptions = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          if (showAdvancedOptions)
                            Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(l10n.advancedOptionsPlanned),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Btn.cancel(onTap: () => Navigator.of(context).pop()),
          Btn.ok(
            onTap: _hasAvailableTargets
                ? () {
                    final currentTab = DefaultTabController.of(context).index;
                    final taskType = switch (currentTab) {
                      1 => 'torrent',
                      2 => 'metalink',
                      _ => 'uri',
                    };
                    _submitTask(taskType);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
