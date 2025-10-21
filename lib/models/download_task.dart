import 'package:aria2_desktop/models/enums/download_enums.dart';

// 下载任务数据模型
class DownloadTask {
  // 任务唯一标识符
  final String id;
  // 任务名称
  final String name;
  // 任务状态
  final DownloadStatus status;
  // 任务详细状态
  final String taskStatus;
  // 下载目录
  final String? dir;
  // 下载进度 (0-1)
  final double progress;
  // 完成大小
  final String completedSize;
  // 总大小
  final String size;
  // 下载速度
  final String downloadSpeed;
  // 上传速度
  final String uploadSpeed;
  // 剩余时间
  final String? remainingTime;
  // 实例ID
  final String instanceId;
  // 是否本地任务
  final bool? isLocal;
  // 下载链接
  final List<String>? uris;
  // 文件列表
  final List<dynamic>? files;
  // 错误信息
  final String? error;
  // Bitfield信息（用于区块可视化）
  final String? bitfield;
  // bittorrent信息（保留以兼容不同数据格式）
  final String? bittorrentInfo;

  DownloadTask({
    required this.id,
    required this.name,
    required this.status,
    required this.taskStatus,
    this.dir,
    required this.progress,
    required this.completedSize,
    required this.size,
    required this.downloadSpeed,
    required this.uploadSpeed,
    this.remainingTime,
    required this.instanceId,
    this.isLocal,
    this.uris,
    this.files,
    this.error,
    this.bitfield,
    this.bittorrentInfo,
  });

  // 从JSON创建实例的工厂方法
  factory DownloadTask.fromJson(Map<String, dynamic> json, String instanceId, {bool isLocal = false}) {
    // 将任务状态字符串转换为DownloadStatus枚举
    DownloadStatus parseStatus(String statusStr) {
      switch (statusStr) {
        case 'active':
          return DownloadStatus.active;
        case 'waiting':
          return DownloadStatus.waiting;
        case 'stopped':
          return DownloadStatus.stopped;
        default:
          return DownloadStatus.waiting;
      }
    }

    return DownloadTask(
      id: json['gid'] as String? ?? '',
      name: json['files']?[0]?['path']?[json['files']?[0]?['path']?.length - 1] as String? ?? 
            json['bittorrent']?['info']?['name'] as String? ?? 
            json['infoHash'] as String? ?? 
            '未知名称',
      status: parseStatus(json['status'] as String? ?? 'waiting'),
      taskStatus: json['status'] as String? ?? 'unknown',
      dir: json['dir'] as String?,
      progress: (json['completedLength'] as num? ?? 0) / (json['totalLength'] as num? ?? 1),
      completedSize: json['completedLength'] as String? ?? '0',
      size: json['totalLength'] as String? ?? '0',
      downloadSpeed: json['downloadSpeed'] as String? ?? '0',
      uploadSpeed: json['uploadSpeed'] as String? ?? '0',
      remainingTime: json['remainingTime'] as String?,
      instanceId: instanceId,
      isLocal: isLocal,
      uris: json['uris'] as List<String>?,
      files: json['files'] as List<dynamic>?,
      error: json['errorMessage'] as String?,
      bitfield: json['bittorrent']?['bitfield'] as String?,
      bittorrentInfo: json['bittorrent'] as String?,
    );
  }
}