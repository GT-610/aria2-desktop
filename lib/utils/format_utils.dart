import 'dart:convert';
import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

class FormatUtils {}

String formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return '0 B';

  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  var i = (log(bytes) / log(1024)).floor();
  i = i.clamp(0, suffixes.length - 1);

  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

String formatRemainingTime({
  required int totalBytes,
  required int completedBytes,
  required int downloadSpeedBytes,
}) {
  if (totalBytes <= 0) {
    return '--';
  }

  final remainingBytes = totalBytes - completedBytes;
  if (remainingBytes <= 0) {
    return '0s';
  }

  if (downloadSpeedBytes <= 0) {
    return '--';
  }

  final remainingSeconds = (remainingBytes / downloadSpeedBytes).ceil();
  if (remainingSeconds < 60) {
    return '${remainingSeconds}s';
  }
  if (remainingSeconds < 3600) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
  if (remainingSeconds < 86400) {
    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  final days = remainingSeconds ~/ 86400;
  final hours = (remainingSeconds % 86400) ~/ 3600;
  return '${days}d ${hours}h';
}

List<int> parseHexBitfield(String bitfield) {
  final pieces = <int>[];

  for (var i = 0; i < bitfield.length; i++) {
    try {
      pieces.add(int.parse(bitfield[i], radix: 16));
    } catch (e) {
      pieces.add(0);
    }
  }

  return pieces;
}

String? parseBitfield(String? bittorrentInfo) {
  if (bittorrentInfo != null && bittorrentInfo.isNotEmpty) {
    try {
      final bittorrentData =
          json.decode(bittorrentInfo) as Map<String, dynamic>;
      if (bittorrentData.containsKey('bitfield') &&
          bittorrentData['bitfield'] is String) {
        return bittorrentData['bitfield'] as String;
      }
      if (bittorrentData.containsKey('info') && bittorrentData['info'] is Map) {
        final info = bittorrentData['info'] as Map<String, dynamic>;
        if (info.containsKey('bitfield') && info['bitfield'] is String) {
          return info['bitfield'] as String;
        }
      }
    } catch (e) {
      lprint('[FormatUtils] Failed to parse bitfield: $e');
    }
  }
  return null;
}

Color getPieceColor(int pieceValue) {
  switch (pieceValue) {
    case 0:
      return Colors.grey;
    case 1:
    case 2:
    case 3:
      return Colors.orange;
    case 4:
    case 5:
    case 6:
    case 7:
      return Colors.yellow;
    case 8:
    case 9:
    case 10:
    case 11:
      return Colors.lightGreen;
    case 12:
    case 13:
    case 14:
    case 15:
      return Colors.green;
    default:
      return Colors.grey;
  }
}
