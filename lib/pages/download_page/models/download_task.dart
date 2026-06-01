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
}
