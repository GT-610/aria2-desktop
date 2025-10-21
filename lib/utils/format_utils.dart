// 格式化字节数显示
String formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return '0 B';
  
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  int i = (bytes == 0) ? 0 : (log(bytes) / log(1024)).floor();
  
  // 确保i不会超出suffixes的范围
  i = i.clamp(0, suffixes.length - 1);
  
  return ((bytes / pow(1024, i)).toStringAsFixed(decimals)) + ' ' + suffixes[i];
}

// 计算剩余时间
String calculateRemainingTime(double progress, String downloadSpeed) {
  if (progress >= 1.0 || downloadSpeed == '0' || downloadSpeed.isEmpty) {
    return '已完成';
  }
  
  // 解析下载速度
  int speedBytes = 0;
  final speedRegex = RegExp(r'^(\d+(?:\.\d+)?)\s*([KMG]?)B\/s$');
  final match = speedRegex.firstMatch(downloadSpeed);
  
  if (match != null) {
    final value = double.tryParse(match.group(1) ?? '0') ?? 0;
    final unit = match.group(2) ?? '';
    
    switch (unit) {
      case 'K':
        speedBytes = (value * 1024).toInt();
        break;
      case 'M':
        speedBytes = (value * 1024 * 1024).toInt();
        break;
      case 'G':
        speedBytes = (value * 1024 * 1024 * 1024).toInt();
        break;
      default:
        speedBytes = value.toInt();
        break;
    }
  }
  
  // 如果速度为0，返回未知
  if (speedBytes == 0) {
    return '未知';
  }
  
  // 计算剩余秒数
  double remainingPercentage = 1.0 - progress;
  // 这里假设总大小为100%，实际应用中需要根据实际大小计算
  int remainingSeconds = (remainingPercentage / (speedBytes / 100)).toInt();
  
  // 格式化剩余时间
  if (remainingSeconds < 60) {
    return '$remainingSeconds秒';
  } else if (remainingSeconds < 3600) {
    int minutes = remainingSeconds ~/ 60;
    int seconds = remainingSeconds % 60;
    return '${minutes}分${seconds}秒';
  } else if (remainingSeconds < 86400) {
    int hours = remainingSeconds ~/ 3600;
    int minutes = (remainingSeconds % 3600) ~/ 60;
    return '${hours}小时${minutes}分';
  } else {
    int days = remainingSeconds ~/ 86400;
    int hours = (remainingSeconds % 86400) ~/ 3600;
    return '${days}天${hours}小时';
  }
}

// 解析十六进制bitfield为区块状态数组
List<int> parseHexBitfield(String bitfield) {
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

// 解析任务数据获取bitfield
String? parseBitfield(String? bittorrentInfo) {
  if (bittorrentInfo != null && bittorrentInfo.isNotEmpty) {
    try {
      Map<String, dynamic> bittorrentData = json.decode(bittorrentInfo);
      if (bittorrentData.containsKey('bitfield') && bittorrentData['bitfield'] is String) {
        return bittorrentData['bitfield'] as String;
      }
      if (bittorrentData.containsKey('info') && bittorrentData['info'] is Map) {
        Map<String, dynamic> info = bittorrentData['info'] as Map<String, dynamic>;
        if (info.containsKey('bitfield') && info['bitfield'] is String) {
          return info['bitfield'] as String;
        }
      }
    } catch (e) {
      print('解析bittorrentInfo中的bitfield失败: $e');
    }
  }
  return null;
}

// 根据区块值获取对应的颜色
Color getPieceColor(int pieceValue) {
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

// 导入必要的库
import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:convert';