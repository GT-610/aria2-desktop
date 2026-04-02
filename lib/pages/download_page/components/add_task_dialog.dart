import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'directory_picker.dart';
import '../../../utils/logging.dart';

class AddTaskDialog extends StatefulWidget {
  final Future<void> Function(String, String, String, String?) onAddTask;

  const AddTaskDialog({super.key, required this.onAddTask});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> with Loggable {
  String saveLocation = '';
  final TextEditingController uriController = TextEditingController();
  bool showAdvancedOptions = false;
  String? selectedTorrentFilePath;
  String? selectedMetalinkFilePath;

  @override
  void initState() {
    super.initState();
    i('AddTaskDialog initialized');
  }

  @override
  Widget build(BuildContext context) {
    // Use StatefulBuilder to manage UI updates
    return StatefulBuilder(
      builder: (context, setState) {
        // Function to update save location
        void onSaveLocationChanged(String newLocation) {
          setState(() {
            saveLocation = newLocation;
          });
        }

        // Paste from clipboard functionality
        Future<void> pasteFromClipboard() async {
          try {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data != null && data.text != null) {
              uriController.text = data.text!;
              setState(() {});
            }
            i('从剪贴板粘贴功能已实现');
          } catch (e) {
            this.e('Failed to paste', error: e);
          }
        }

        // Select torrent file
        Future<void> selectTorrentFile() async {
          try {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['torrent'],
              dialogTitle: '选择种子文件',
            );

            if (result != null) {
              final filePath = result.files.single.path;
              i('Selected torrent file: $filePath');
              setState(() {
                selectedTorrentFilePath = filePath;
              });
            }
          } catch (e) {
            this.e('Failed to select torrent file', error: e);
          }
        }

        // Select Metalink file
        Future<void> selectMetalinkFile() async {
          try {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['metalink'],
              dialogTitle: '选择Metalink文件',
            );

            if (result != null) {
              final filePath = result.files.single.path;
              i('Selected Metalink file: $filePath');
              setState(() {
                selectedMetalinkFilePath = filePath;
              });
            }
          } catch (e) {
            this.e('Failed to select Metalink file', error: e);
          }
        }

        // Submit task
        Future<void> submitTask(String taskType) async {
          String downloadDir = saveLocation;
          String uri = uriController.text;
          String? fileContent;

          // Read file content if needed
          if (taskType == 'torrent' && selectedTorrentFilePath != null) {
            final file = File(selectedTorrentFilePath!);
            final bytes = await file.readAsBytes();
            fileContent = base64Encode(bytes);
          } else if (taskType == 'metalink' &&
              selectedMetalinkFilePath != null) {
            final file = File(selectedMetalinkFilePath!);
            final bytes = await file.readAsBytes();
            fileContent = base64Encode(bytes);
          }

          // Call callback function to handle task addition
          i(
            'Submit task: type=$taskType, URI=$uri, save directory=$downloadDir, hasFileContent=${fileContent != null}',
          );
          widget.onAddTask(taskType, uri, downloadDir, fileContent);

          // Close dialog
          if (mounted) {
            Navigator.pop(this.context);
          }
        }

        // Use DefaultTabController to simplify TabController management
        return DefaultTabController(
          length: 3,
          initialIndex: 0,
          child: AlertDialog(
            title: const Text('添加任务'),
            content: SizedBox(
              width: 500,
              height: 450,
              child: Column(
                children: [
                  // Tabs
                  const TabBar(
                    tabs: [
                      Tab(text: 'URI'),
                      Tab(text: '种子'),
                      Tab(text: 'Metalink'),
                    ],
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                  // Tab content
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: TabBarView(
                            children: [
                              // URI tab content
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Input(
                                      controller: uriController,
                                      label: 'URL或磁力链接',
                                      hint: '请输入下载链接...',
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 8),
                                    Btn.tile(
                                      text: '从剪贴板粘贴',
                                      icon: const Icon(Icons.paste),
                                      onTap: pasteFromClipboard,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('支持HTTP/HTTPS、FTP、SFTP、磁力链接等'),
                                  ],
                                ),
                              ),
                              // Torrent tab content
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.file_open, size: 64),
                                    const SizedBox(height: 16),
                                    Btn.tile(
                                      text: '选择种子文件',
                                      icon: const Icon(Icons.upload_file),
                                      onTap: selectTorrentFile,
                                    ),
                                    const SizedBox(height: 16),
                                    if (selectedTorrentFilePath != null)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          '已选择: ${selectedTorrentFilePath!.split(Platform.pathSeparator).last}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    const Text('支持.torrent格式的种子文件'),
                                  ],
                                ),
                              ),
                              // Metalink tab content
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.file_open, size: 64),
                                    const SizedBox(height: 16),
                                    Btn.tile(
                                      text: '选择Metalink文件',
                                      icon: const Icon(Icons.upload_file),
                                      onTap: selectMetalinkFile,
                                    ),
                                    const SizedBox(height: 16),
                                    if (selectedMetalinkFilePath != null)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          '已选择: ${selectedMetalinkFilePath!.split(Platform.pathSeparator).last}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    const Text('支持.metalink格式的文件'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Divider
                        const Divider(),
                        // Common area - not affected by tabs
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Save location - using reusable DirectoryPicker component
                              DirectoryPicker(
                                initialDirectory: saveLocation,
                                onDirectoryChanged: onSaveLocationChanged,
                                onError: (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error)),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              // Advanced options switch
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('显示高级选项'),
                                  Switch(
                                    value: showAdvancedOptions,
                                    onChanged: (bool value) {
                                      setState(() {
                                        showAdvancedOptions = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              // Advanced options (hidden state)
                              if (showAdvancedOptions)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Column(
                                    children: [
                                      // More advanced options can be added here
                                      Text('高级选项将在这里显示'),
                                    ],
                                  ),
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
                onTap: () {
                  int currentTab = DefaultTabController.of(context).index;
                  String taskType;

                  switch (currentTab) {
                    case 0:
                      taskType = 'uri';
                      break;
                    case 1:
                      taskType = 'torrent';
                      break;
                    case 2:
                      taskType = 'metalink';
                      break;
                    default:
                      taskType = 'uri';
                  }

                  submitTask(taskType);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
