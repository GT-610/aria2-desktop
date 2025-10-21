import 'package:flutter/material.dart';
import 'package:aria2_desktop/models/download_task.dart';
import 'package:aria2_desktop/components/download/bitfield_visualization.dart';
import 'package:aria2_desktop/utils/format_utils.dart';

// 任务详情对话框组件
class TaskDetailsDialog extends StatefulWidget {
  final DownloadTask task;
  final void Function()? onRefresh;

  const TaskDetailsDialog({super.key, required this.task, this.onRefresh});

  @override
  State<TaskDetailsDialog> createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends State<TaskDetailsDialog> {
  int _selectedTabIndex = 0;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 启动实时刷新（每2秒）
    _startRealTimeRefresh();
  }

  @override
  void dispose() {
    _stopRealTimeRefresh();
    super.dispose();
  }

  // 启动实时刷新
  void _startRealTimeRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (widget.onRefresh != null) {
        setState(() {
          _isRefreshing = true;
        });
        widget.onRefresh!().then((_) {
          if (mounted) {
            setState(() {
              _isRefreshing = false;
            });
          }
        });
      }
    });
  }

  // 停止实时刷新
  void _stopRealTimeRefresh() {
    if (_refreshTimer != null) {
      _refreshTimer!.cancel();
      _refreshTimer = null;
    }
  }

  // 获取状态文本和颜色
  (String, Color) _getStatusInfo(ColorScheme colorScheme) {
    DownloadTask task = widget.task;
    // 检查是否为暂停中任务
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return ('已暂停', colorScheme.tertiary);
    }
    
    // 特殊处理已完成的任务
    if (task.status == DownloadStatus.stopped && task.taskStatus == 'complete') {
      return ('已完成', colorScheme.primaryContainer);
    }
    
    switch (task.status) {
      case DownloadStatus.active:
        return ('下载中', colorScheme.primary);
      case DownloadStatus.waiting:
        return ('等待中', colorScheme.secondary);
      case DownloadStatus.stopped:
        return ('已停止', colorScheme.errorContainer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (statusText, statusColor) = _getStatusInfo(colorScheme);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              '任务详情',
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (_isRefreshing)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              TabBar(
                tabs: const [
                  Tab(text: '总览'),
                  Tab(text: '下载状态'),
                  Tab(text: '文件列表'),
                ],
                onTap: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                  });
                },
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // 总览标签页
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 任务名称
                          Text('任务名称:', style: theme.textTheme.titleMedium),
                          Text(widget.task.name, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          
                          // 任务ID
                          Text('任务ID:', style: theme.textTheme.titleMedium),
                          Text(widget.task.id, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          
                          // 状态信息
                          Text('状态:', style: theme.textTheme.titleMedium),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // 进度信息
                          Text('进度:', style: theme.textTheme.titleMedium),
                          LinearProgressIndicator(
                            value: widget.task.progress,
                            borderRadius: BorderRadius.circular(10),
                            minHeight: 8,
                            backgroundColor: colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(widget.task.progress * 100).toStringAsFixed(2)}% - ${widget.task.completedSize} / ${widget.task.size}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          
                          // 速度信息
                          Text('速度:', style: theme.textTheme.titleMedium),
                          Row(
                            children: [
                              Text('下载: ${widget.task.downloadSpeed}', style: theme.textTheme.bodyMedium),
                              const SizedBox(width: 16),
                              Text('上传: ${widget.task.uploadSpeed}', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // 剩余时间
                          Text('剩余时间:', style: theme.textTheme.titleMedium),
                          Text(
                            calculateRemainingTime(widget.task.progress, widget.task.downloadSpeed),
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          
                          // 下载目录
                          if (widget.task.dir != null && widget.task.dir!.isNotEmpty) ...[
                            Text('下载目录:', style: theme.textTheme.titleMedium),
                            Text(widget.task.dir!, style: theme.textTheme.bodyMedium),
                          ],
                          
                          // 错误信息
                          if (widget.task.error != null && widget.task.error!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text('错误信息:', style: theme.textTheme.titleMedium),
                            Text(widget.task.error!, style: TextStyle(color: colorScheme.error)),
                          ],
                        ],
                      ),
                    ),
                    
                    // 下载状态标签页 - 显示区块可视化
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: BitfieldVisualization(task: widget.task),
                    ),
                    
                    // 文件列表标签页
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('文件列表:', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 16),
                          if (widget.task.files != null && widget.task.files!.isNotEmpty) 
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: widget.task.files!.length,
                              itemBuilder: (context, index) {
                                final file = widget.task.files![index];
                                String? fileName;
                                String? fileSize;
                                double fileProgress = 0;
                                
                                if (file is Map && file.containsKey('path') && file['path'] is List) {
                                  List path = file['path'] as List;
                                  if (path.isNotEmpty) {
                                    fileName = path.last.toString();
                                  }
                                }
                                
                                if (file is Map) {
                                  if (file.containsKey('length') && file.containsKey('completedLength')) {
                                    int totalLength = int.tryParse(file['length'].toString()) ?? 0;
                                    int completedLength = int.tryParse(file['completedLength'].toString()) ?? 0;
                                    fileProgress = totalLength > 0 ? completedLength / totalLength : 0;
                                    fileSize = formatBytes(totalLength);
                                  }
                                }
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(fileName ?? '未知文件名', style: theme.textTheme.bodyMedium),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: fileProgress,
                                          borderRadius: BorderRadius.circular(4),
                                          minHeight: 4,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${(fileProgress * 100).toStringAsFixed(2)}% - $fileSize',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            Text('没有文件信息', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

// 导入必要的库
import 'dart:async';