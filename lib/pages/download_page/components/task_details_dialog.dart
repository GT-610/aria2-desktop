import 'dart:async';
import 'package:flutter/material.dart';
import '../../../utils/format_utils.dart';
import '../models/download_task.dart';
import '../utils/task_utils.dart';
import '../enums.dart';

/// 任务详情对话框组件
class TaskDetailsDialog {
  /// 显示任务详情对话框
  static Future<void> showTaskDetailsDialog(
    BuildContext context,
    DownloadTask initialTask,
    List<DownloadTask> allTasks,
    (String, Color) Function(DownloadTask, ColorScheme) getStatusInfo,
  ) async {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Get the latest task data from the main loop's task list
            DownloadTask getLatestTaskData() {
              // 优先从主循环的任务列表中查找
              final taskFromList = allTasks.firstWhere(
                (t) => t.id == initialTask.id,
                orElse: () => initialTask, // 如果找不到，使用传入的task作为默认值
              );
              return taskFromList;
            }
            
            // 创建一个每秒刷新一次的定时器，与主循环的刷新频率保持一致
            // 这样详情页面可以实时显示最新的任务状态
            Timer? refreshTimer;
            refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
              if (context.mounted) {
                setState(() {
                  // 触发重建，从主循环获取最新数据
                });
              }
            });
            
            // 添加对话框关闭时的清理操作
            void disposeResources() {
              if (refreshTimer != null) {
                refreshTimer!.cancel();
                refreshTimer = null;
              }
            }
            
            // 获取最新的任务数据
            final currentTask = getLatestTaskData();
                  
            return WillPopScope(
              onWillPop: () async {
                disposeResources();
                return true;
              },
              child: DefaultTabController(
                length: 3,
                initialIndex: 0,
                child: AlertDialog(
                  title: Text('任务详情 - ${currentTask.name}'),
                  content: SizedBox(
                    width: 600,
                    height: 450,
                    child: Column(
                      children: [
                        // 标签栏
                        TabBar(
                          tabs: const [
                            Tab(text: '总览'),
                            Tab(text: '下载状态'),
                            Tab(text: '文件列表'),
                          ],
                          indicatorSize: TabBarIndicatorSize.tab,
                        ),
                        // 标签页内容
                        Expanded(
                          child: TabBarView(
                            children: [
                              // 总览标签页 - 显示扩展的详细信息
                              SingleChildScrollView(
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 基本信息
                                    Text('任务ID: ${currentTask.id}'),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text('任务状态: '),
                                        Text(
                                          getStatusInfo(currentTask, Theme.of(context).colorScheme).$1,
                                          style: TextStyle(color: getStatusInfo(currentTask, Theme.of(context).colorScheme).$2),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Text('任务大小: ${currentTask.size} (${currentTask.totalLengthBytes} 字节)'),
                                    SizedBox(height: 8),
                                    Text('已下载: ${currentTask.completedSize} (${currentTask.completedLengthBytes} 字节)'),
                                    SizedBox(height: 8),
                                    Text('进度: ${(currentTask.progress * 100).toStringAsFixed(2)}%'),
                                    SizedBox(height: 12),
                                    // 速度信息
                                    Text('下载速度: ${currentTask.downloadSpeed} (${currentTask.downloadSpeedBytes} 字节/秒)'),
                                    SizedBox(height: 8),
                                    Text('上传速度: ${currentTask.uploadSpeed} (${currentTask.uploadSpeedBytes} 字节/秒)'),
                                    SizedBox(height: 12),
                                    // 其他信息
                                    Text('连接数: ${currentTask.connections ?? '--'}'),
                                    SizedBox(height: 8),
                                    Text('下载路径: ${currentTask.dir ?? '--'}'),
                                    SizedBox(height: 8),
                                    // 显示错误信息（如果有）
                                    if (currentTask.errorMessage != null && currentTask.errorMessage!.isNotEmpty) 
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('错误信息: ${currentTask.errorMessage}', style: TextStyle(color: Colors.red)),
                                          SizedBox(height: 8),
                                        ],
                                      ),
                                    // 计算并显示剩余时间
                                    if (currentTask.status == DownloadStatus.active && currentTask.downloadSpeedBytes > 0)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('剩余时间: ${TaskUtils.calculateRemainingTime(currentTask.progress, currentTask.downloadSpeed)}'),
                                          SizedBox(height: 8),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                               
                              // 区块信息标签页 - 实现可视化展示
                              SingleChildScrollView(
                                padding: EdgeInsets.all(16),
                                child: _buildBitfieldVisualization(currentTask),
                              ),
                                
                              // 文件信息标签页 - 显示在文件列表标签下
                              SingleChildScrollView(
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('文件列表:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    SizedBox(height: 8),
                                    if (currentTask.files != null && currentTask.files!.isNotEmpty) 
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: currentTask.files!.length,
                                        itemBuilder: (context, index) {
                                          final file = currentTask.files![index];
                                          final filePath = file['path'] as String? ?? '未知路径';
                                          final fileName = filePath.split('/').last.split('\\').last;
                                          final fileSize = formatBytes(int.tryParse(file['length'] as String? ?? '0') ?? 0);
                                          final completedSize = formatBytes(int.tryParse(file['completedLength'] as String? ?? '0') ?? 0);
                                          final selected = (file['selected'] as String? ?? 'true') == 'true';
                                            
                                          return Container(
                                            padding: EdgeInsets.symmetric(vertical: 4),
                                            decoration: BoxDecoration(
                                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(fileName, style: TextStyle(fontWeight: selected ? FontWeight.normal : FontWeight.w300)),
                                                Row(
                                                  children: [
                                                    Text('$completedSize / $fileSize'),
                                                    if (!selected) Text(' (未选择)', style: TextStyle(color: Colors.grey)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      Text('无文件信息'),
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
                        disposeResources();
                        Navigator.of(context).pop();
                      },
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // 对话框关闭时清除状态
    });
  }
  
  // 构建区块可视化
  static Widget _buildBitfieldVisualization(DownloadTask task) {
    // 直接从任务对象获取bitfield
    String? bitfield = task.bitfield;
    
    if (bitfield == null || bitfield.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '当前任务没有区块信息',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '任务可能尚未开始或没有可用的区块数据',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // 解析bitfield为区块状态数组
    List<int> pieces = _parseHexBitfield(bitfield);
    
    // 计算统计信息
    int totalPieces = pieces.length;
    int completedPieces = pieces.where((piece) => piece == 15).length; // 完全下载完成 (f)
    int partialPieces = pieces.where((piece) => piece > 0 && piece < 15).length; // 部分下载 (1-14)
    int missingPieces = pieces.where((piece) => piece == 0).length; // 未下载 (0)
    
    // 计算完成百分比
    double completionPercentage = totalPieces > 0 
      ? ((completedPieces + partialPieces * 0.5) / totalPieces) * 100 
      : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 统计信息
        Card(
          elevation: 2,
          margin: EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('区块统计:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('总区块数:'),
                    Text('$totalPieces'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, color: Colors.green, margin: EdgeInsets.only(right: 8)),
                        Text('已完成:'),
                      ],
                    ),
                    Text('$completedPieces'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, color: Colors.yellow, margin: EdgeInsets.only(right: 8)),
                        Text('部分完成:'),
                      ],
                    ),
                    Text('$partialPieces'),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, color: Colors.grey, margin: EdgeInsets.only(right: 8)),
                        Text('未下载:'),
                      ],
                    ),
                    Text('$missingPieces'),
                  ],
                ),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completionPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                SizedBox(height: 4),
                Text('区块完成度: ${completionPercentage.toStringAsFixed(2)}%', textAlign: TextAlign.right),
              ],
            ),
          ),
        ),
        
        // 下载状态可视化网格
        Text('下载状态分布:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 12),
        _buildPiecesGrid(pieces),
        
        // 图例说明
        SizedBox(height: 16),
        Card(
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('图例说明:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.green, margin: EdgeInsets.only(right: 8)),
                    Text('完全下载完成 (f)'),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.lightGreen, margin: EdgeInsets.only(right: 8)),
                    Text('高完成度 (8-b)'),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.yellow, margin: EdgeInsets.only(right: 8)),
                    Text('中等完成度 (4-7)'),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.orange, margin: EdgeInsets.only(right: 8)),
                    Text('低完成度 (1-3)'),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, color: Colors.grey, margin: EdgeInsets.only(right: 8)),
                    Text('未下载 (0)'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 解析十六进制bitfield为区块状态数组
  static List<int> _parseHexBitfield(String bitfield) {
    List<int> pieces = [];
    
    // 每个字符代表一个区块的状态 (0-f)
    for (int i = 0; i < bitfield.length; i++) {
      String hexChar = bitfield[i];
      try {
        int pieceValue = int.parse(hexChar, radix: 16);
        pieces.add(pieceValue);
      } catch (e) {
        // 如果解析失败，默认为未下载
        pieces.add(0);
      }
    }
    
    return pieces;
  }
  
  // 构建区块网格可视化
  static Widget _buildPiecesGrid(List<int> pieces) {
    // 根据区块数量确定网格大小
    double pieceSize = pieces.length > 1000 ? 4.0 : (pieces.length > 500 ? 6.0 : 8.0);
    
    return Wrap(
      spacing: 1.0,
      runSpacing: 1.0,
      children: List.generate(pieces.length, (index) {
        return Container(
          width: pieceSize,
          height: pieceSize,
          decoration: BoxDecoration(
            color: _getPieceColor(pieces[index]),
            border: Border.all(width: 0.5, color: Colors.black.withValues(alpha: 0.1)),
          ),
        );
      }),
    );
  }
  
  // 根据区块值获取对应的颜色
  static Color _getPieceColor(int pieceValue) {
    switch (pieceValue) {
      case 0:
        return Colors.grey; // 未下载
      case 1:
      case 2:
      case 3:
        return Colors.orange; // 低完成度
      case 4:
      case 5:
      case 6:
      case 7:
        return Colors.yellow; // 中等完成度
      case 8:
      case 9:
      case 10:
      case 11:
        return Colors.lightGreen; // 高完成度
      case 12:
      case 13:
      case 14:
      case 15:
        return Colors.green; // 完全下载完成
      default:
        return Colors.grey; // 默认未下载
    }
  }
}