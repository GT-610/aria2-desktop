import 'package:flutter/material.dart';
import 'package:aria2_desktop/models/download_task.dart';
import 'package:aria2_desktop/utils/format_utils.dart';

// 区块可视化组件
class BitfieldVisualization extends StatelessWidget {
  final DownloadTask task;

  const BitfieldVisualization({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
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
    List<int> pieces = parseHexBitfield(bitfield);
    
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

  // 构建区块网格可视化
  Widget _buildPiecesGrid(List<int> pieces) {
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
            color: getPieceColor(pieces[index]),
            border: Border.all(width: 0.5, color: Colors.black.withOpacity(0.1)),
          ),
        );
      }),
    );
  }
}