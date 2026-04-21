import '../enums.dart';

class DownloadTask {
  final String id;
  final String name;
  final DownloadStatus status;
  final String? taskStatus;
  final double progress;
  final String downloadSpeed;
  final String uploadSpeed;
  final String size;
  final String completedSize;
  final bool isLocal;
  final String instanceId;
  final int? connections;
  final int? numSeeders;
  final String? dir;
  final int totalLengthBytes;
  final int completedLengthBytes;
  final int uploadLengthBytes;
  final int downloadSpeedBytes;
  final int uploadSpeedBytes;
  final List<Map<String, dynamic>>? files;
  final String? bittorrentInfo;
  final List<String>? trackers;
  final List<String>? uris;
  final String? errorMessage;
  final DateTime? startTime;
  final String? bitfield;
  final String? infoHash;
  final int? pieceLength;
  final int? numPieces;
  final bool isSeeder;

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
    this.numSeeders,
    this.dir,
    this.totalLengthBytes = 0,
    this.completedLengthBytes = 0,
    this.uploadLengthBytes = 0,
    this.downloadSpeedBytes = 0,
    this.uploadSpeedBytes = 0,
    this.files,
    this.bittorrentInfo,
    this.trackers,
    this.uris,
    this.errorMessage,
    this.startTime,
    this.bitfield,
    this.infoHash,
    this.pieceLength,
    this.numPieces,
    this.isSeeder = false,
  });

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      status: _parseDownloadStatus(json['status']),
      taskStatus: json['taskStatus'],
      progress: (json['progress'] ?? 0.0).toDouble(),
      downloadSpeed: json['downloadSpeed'] ?? '0 B/s',
      uploadSpeed: json['uploadSpeed'] ?? '0 B/s',
      size: json['size'] ?? '0 B',
      completedSize: json['completedSize'] ?? '0 B',
      isLocal: json['isLocal'] ?? false,
      instanceId: json['instanceId'] ?? '',
      connections: json['connections'],
      numSeeders: json['numSeeders'],
      dir: json['dir'],
      totalLengthBytes: json['totalLengthBytes'] ?? 0,
      completedLengthBytes: json['completedLengthBytes'] ?? 0,
      uploadLengthBytes: json['uploadLengthBytes'] ?? 0,
      downloadSpeedBytes: json['downloadSpeedBytes'] ?? 0,
      uploadSpeedBytes: json['uploadSpeedBytes'] ?? 0,
      files: json['files'] != null
          ? List<Map<String, dynamic>>.from(json['files'])
          : null,
      bittorrentInfo: json['bittorrentInfo'],
      trackers: json['trackers'] != null
          ? List<String>.from(json['trackers'])
          : null,
      uris: json['uris'] != null ? List<String>.from(json['uris']) : null,
      errorMessage: json['errorMessage'],
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'])
          : null,
      bitfield: json['bitfield'],
      infoHash: json['infoHash'],
      pieceLength: json['pieceLength'],
      numPieces: json['numPieces'],
      isSeeder: json['isSeeder'] ?? false,
    );
  }

  static DownloadStatus _parseDownloadStatus(dynamic value) {
    if (value == null) return DownloadStatus.stopped;
    if (value is DownloadStatus) return value;
    if (value is String) {
      try {
        return DownloadStatus.values.byName(value);
      } catch (_) {
        return DownloadStatus.stopped;
      }
    }
    return DownloadStatus.stopped;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status.name,
      'taskStatus': taskStatus,
      'progress': progress,
      'downloadSpeed': downloadSpeed,
      'uploadSpeed': uploadSpeed,
      'size': size,
      'completedSize': completedSize,
      'isLocal': isLocal,
      'instanceId': instanceId,
      'connections': connections,
      'numSeeders': numSeeders,
      'dir': dir,
      'totalLengthBytes': totalLengthBytes,
      'completedLengthBytes': completedLengthBytes,
      'uploadLengthBytes': uploadLengthBytes,
      'downloadSpeedBytes': downloadSpeedBytes,
      'uploadSpeedBytes': uploadSpeedBytes,
      'files': files,
      'bittorrentInfo': bittorrentInfo,
      'trackers': trackers,
      'uris': uris,
      'errorMessage': errorMessage,
      'startTime': startTime?.toIso8601String(),
      'bitfield': bitfield,
      'infoHash': infoHash,
      'pieceLength': pieceLength,
      'numPieces': numPieces,
      'isSeeder': isSeeder,
    };
  }
}
