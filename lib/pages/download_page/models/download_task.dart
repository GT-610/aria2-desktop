import '../enums.dart';

// Enhanced Download task model with more detailed information
class DownloadTask {
  final String id;
  final String name;
  final DownloadStatus status;
  final String? taskStatus; // Store original task status, e.g. 'paused'
  final double progress;
  final String downloadSpeed;
  final String uploadSpeed;
  final String size;
  final String completedSize;
  final bool isLocal;
  final String instanceId; // Add instance ID field
  final int? connections; // 连接数信息
  final String? dir; // 下载路径
  
  // Extended detailed information
  final int totalLengthBytes; // Raw bytes for accurate calculations
  final int completedLengthBytes; // Raw bytes for accurate calculations
  final int downloadSpeedBytes; // Raw bytes for accurate calculations
  final int uploadSpeedBytes; // Raw bytes for accurate calculations
  final List<Map<String, dynamic>>? files; // File list with detailed information
  final String? bittorrentInfo; // Torrent info if available
  final List<String>? uris; // Download URIs
  final String? errorMessage; // Error message if any
  final DateTime? startTime; // Task start time
  final String? bitfield; // Bitfield data for download status visualization

  DownloadTask({
    required this.id,
    required this.name,
    required this.status,
    this.taskStatus,
    required this.progress,
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.size,
    required this.completedSize,
    required this.isLocal,
    required this.instanceId,
    this.connections,
    this.dir,
    this.totalLengthBytes = 0,
    this.completedLengthBytes = 0,
    this.downloadSpeedBytes = 0,
    this.uploadSpeedBytes = 0,
    this.files,
    this.bittorrentInfo,
    this.uris,
    this.errorMessage,
    this.startTime,
    this.bitfield,
  });
}