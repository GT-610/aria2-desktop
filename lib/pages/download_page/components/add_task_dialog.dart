import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'directory_picker.dart';
import '../../../utils/logging/log_extensions.dart';

// Add task dialog component
class AddTaskDialog extends StatefulWidget {
  final Function(String, String, String) onAddTask;

  const AddTaskDialog({super.key, required this.onAddTask});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> with Loggable {
  @override
  void initState() {
    super.initState();
    initLogger();
    logger.i('AddTaskDialog initialized');
  }

  @override
  Widget build(BuildContext context) {
    // Create text controller outside the dialog to ensure state persistence
    String saveLocation = '';
    final TextEditingController uriController = TextEditingController();
    bool showAdvancedOptions = false;

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
            // Note: Need to import services package to use Clipboard
            // final data = await Clipboard.getData(Clipboard.kTextPlain);
            // if (data != null && data.text != null) {
            //   uriController.text = data.text!;
            //   setState(() {});
            // }
            // Since services package is not imported, use placeholder implementation here
            logger.d('从剪贴板粘贴功能需要实现');
          } catch (e) {
            logger.e('Failed to paste', error: e);
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
              logger.i('Selected torrent file: ${result.files.single.path}');
              // Seed file upload logic should be implemented here
            }
          } catch (e) {
            logger.e('Failed to select torrent file', error: e);
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
              logger.i('Selected Metalink file: ${result.files.single.path}');
              // Metalink file upload logic should be implemented here
            }
          } catch (e) {
            logger.e('Failed to select Metalink file', error: e);
          }
        }

        // Submit task
        void submitTask(String taskType) {
          String downloadDir = saveLocation;
          String uri = uriController.text;
          
          // Call callback function to handle task addition
          logger.i('Submit task: type=$taskType, URI=$uri, save directory=$downloadDir');
          widget.onAddTask(taskType, uri, downloadDir);
          
          // Close dialog
          Navigator.pop(context);
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
                                    TextField(
                                      controller: uriController,
                                      decoration: const InputDecoration(
                                        labelText: 'URL或磁力链接',
                                        hintText: '请输入下载链接...',
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: pasteFromClipboard,
                                      child: const Text('从剪贴板粘贴'),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('支持HTTP/HTTPS、FTP、SFTP、磁力链接等'),
                                  ],
                                ),
                              ),
                              // Torrent tab content
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.file_open, size: 64),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: selectTorrentFile,
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('选择种子文件'),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('支持.torrent格式的种子文件'),
                                  ],
                                ),
                              ),
                              // Metalink tab content
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.file_open, size: 64),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: selectMetalinkFile,
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('选择Metalink文件'),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  // Implement add task functionality based on currently selected tab
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
                child: const Text('确认'),
              ),
            ],
          ),
        );
      },
    );
  }
}