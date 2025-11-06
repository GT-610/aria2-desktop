import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'directory_picker.dart';

// 添加任务对话框组件
class AddTaskDialog extends StatelessWidget {
  final Function(String, String, String) onAddTask;

  const AddTaskDialog({super.key, required this.onAddTask});

  @override
  Widget build(BuildContext context) {
    // 在对话框外部创建文本控制器，确保状态的持久性
    String saveLocation = '';
    final TextEditingController uriController = TextEditingController();
    bool showAdvancedOptions = false;

    // 使用StatefulBuilder来管理UI更新
    return StatefulBuilder(
      builder: (context, setState) {
        // 更新保存位置的函数
        void _onSaveLocationChanged(String newLocation) {
          setState(() {
            saveLocation = newLocation;
          });
        }

        // 从剪贴板粘贴功能
        Future<void> _pasteFromClipboard() async {
          try {
            // 注意：这里需要导入services包来使用Clipboard
            // final data = await Clipboard.getData(Clipboard.kTextPlain);
            // if (data != null && data.text != null) {
            //   uriController.text = data.text!;
            //   setState(() {});
            // }
            // 由于没有导入services包，这里先用占位符实现
            print('从剪贴板粘贴功能需要实现');
          } catch (e) {
            print('粘贴失败: $e');
          }
        }

        // 选择种子文件
        Future<void> _selectTorrentFile() async {
          try {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['torrent'],
              dialogTitle: '选择种子文件',
            );
            
            if (result != null) {
              print('选择的种子文件: ${result.files.single.path}');
              // 这里应该实现上传种子文件的逻辑
            }
          } catch (e) {
            print('选择种子文件失败: $e');
          }
        }

        // 选择Metalink文件
        Future<void> _selectMetalinkFile() async {
          try {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['metalink'],
              dialogTitle: '选择Metalink文件',
            );
            
            if (result != null) {
              print('选择的Metalink文件: ${result.files.single.path}');
              // 这里应该实现上传Metalink文件的逻辑
            }
          } catch (e) {
            print('选择Metalink文件失败: $e');
          }
        }

        // 提交任务
        void _submitTask(String taskType) {
          String downloadDir = saveLocation;
          String uri = uriController.text;
          
          // 调用回调函数处理任务添加
          onAddTask(taskType, uri, downloadDir);
          
          // 关闭对话框
          Navigator.pop(context);
        }

        // 使用DefaultTabController来简化TabController的管理
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
                  // 选项卡
                  const TabBar(
                    tabs: [
                      Tab(text: 'URI'),
                      Tab(text: '种子'),
                      Tab(text: 'Metalink'),
                    ],
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                  // 选项卡内容
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: TabBarView(
                            children: [
                              // URI 选项卡内容
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
                                      onPressed: _pasteFromClipboard,
                                      child: const Text('从剪贴板粘贴'),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('支持HTTP/HTTPS、FTP、SFTP、磁力链接等'),
                                  ],
                                ),
                              ),
                              // 种子 选项卡内容
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.file_open, size: 64),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: _selectTorrentFile,
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('选择种子文件'),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('支持.torrent格式的种子文件'),
                                  ],
                                ),
                              ),
                              // Metalink 选项卡内容
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.file_open, size: 64),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: _selectMetalinkFile,
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
                        // 分隔线
                        const Divider(),
                        // 公共区域 - 不受选项卡影响
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 保存位置 - 使用可复用的DirectoryPicker组件
                              DirectoryPicker(
                                initialDirectory: saveLocation,
                                onDirectoryChanged: _onSaveLocationChanged,
                                onError: (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error)),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              // 高级选项开关
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
                              // 高级选项（隐藏状态）
                              if (showAdvancedOptions)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Column(
                                    children: [
                                      // 这里可以添加更多高级选项
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
                  // 根据当前选中的选项卡实现添加任务功能
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
                  
                  _submitTask(taskType);
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