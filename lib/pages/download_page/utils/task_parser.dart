import 'dart:convert';
import '../enums.dart';
import '../models/download_task.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/logging.dart';

// Utility class for parsing task data from RPC responses
class TaskParser {
  static final AppLogger _logger = AppLogger('TaskParser');
  // Parse a list of tasks
  static List<DownloadTask> parseTasks(List tasks, DownloadStatus status, String instanceId, bool isLocal) {
    List<DownloadTask> parsedTasks = [];
    
    for (var taskData in tasks) {
      if (taskData is Map) {
          try {
            // Create task with correct status
            final taskDataMap = taskData as Map<String, dynamic>;
            final parsedTask = parseTask(taskDataMap, instanceId, isLocal);
            // Create a new task object with the correct status
            final taskWithStatus = DownloadTask(
              id: parsedTask.id,
              name: parsedTask.name,
              status: status, // Use the status passed to the function
              taskStatus: parsedTask.taskStatus,
              progress: parsedTask.progress,
              downloadSpeed: parsedTask.downloadSpeed,
              uploadSpeed: parsedTask.uploadSpeed,
              size: parsedTask.size,
              completedSize: parsedTask.completedSize,
              isLocal: parsedTask.isLocal,
              instanceId: parsedTask.instanceId,
              connections: parsedTask.connections,
              dir: parsedTask.dir,
              totalLengthBytes: parsedTask.totalLengthBytes,
              completedLengthBytes: parsedTask.completedLengthBytes,
              downloadSpeedBytes: parsedTask.downloadSpeedBytes,
              uploadSpeedBytes: parsedTask.uploadSpeedBytes,
              files: parsedTask.files,
              bittorrentInfo: parsedTask.bittorrentInfo,
              uris: parsedTask.uris,
              errorMessage: parsedTask.errorMessage,
              startTime: parsedTask.startTime,
              bitfield: parsedTask.bitfield,
            );
            parsedTasks.add(taskWithStatus);
          } catch (e) {
            _logger.e('Failed to parse task', error: e);
            continue;
          }
        }
    }
    
    return parsedTasks;
  }

  // Parse a single task
  static DownloadTask parseTask(Map<String, dynamic> taskData, String instanceId, bool isLocal) {
    // Parse raw bytes data first for accurate calculations and storage
    final totalLengthBytes = int.tryParse(taskData['totalLength'] as String? ?? '0') ?? 0;
    final completedLengthBytes = int.tryParse(taskData['completedLength'] as String? ?? '0') ?? 0;
    final downloadSpeedBytes = int.tryParse(taskData['downloadSpeed'] as String? ?? '0') ?? 0;
    final uploadSpeedBytes = int.tryParse(taskData['uploadSpeed'] as String? ?? '0') ?? 0;
    
    // Basic fields
    String id = taskData['gid'] as String? ?? '';
    String? taskStatus = taskData['status'] as String?;
    
    // Calculate progress
    double progress = totalLengthBytes > 0 ? completedLengthBytes / totalLengthBytes : 0.0;
    
    // Format display values
    String size = formatBytes(totalLengthBytes);
    String completedSize = formatBytes(completedLengthBytes);
    String downloadSpeed = '${formatBytes(downloadSpeedBytes)}/s';
    String uploadSpeed = '${formatBytes(uploadSpeedBytes)}/s';
    
    // Get file name and store complete files info
    String name = '';
    List<Map<String, dynamic>>? files;
    
    if (taskData.containsKey('files') && taskData['files'] is List && (taskData['files'] as List).isNotEmpty) {
      // Store complete files information for detailed view
      files = (taskData['files'] as List).map((file) {
        if (file is Map) {
          return <String, dynamic>{
            ...file,
            'path': file['path'] as String? ?? '',
            'length': file['length'] as String? ?? '0',
            'completedLength': file['completedLength'] as String? ?? '0',
            'selected': file['selected'] as String? ?? 'true',
          };
        }
        return <String, dynamic>{};
      }).toList();
      
      // Extract first file name for display
      final firstFile = (taskData['files'] as List)[0];
      if (firstFile is Map && firstFile.containsKey('path')) {
        final path = firstFile['path'] as String;
        name = path.split('/').last.split('\\').last;
      }
    }
    
    // Parse additional details for the extended model
    int? connections = taskData.containsKey('connections') 
      ? int.tryParse(taskData['connections'] as String? ?? '')
      : null;
    
    String? dir = taskData['dir'] as String?;
    
    // Parse torrent info if available
    String? bittorrentInfo;
    if (taskData.containsKey('bittorrent') && taskData['bittorrent'] is Map) {
      bittorrentInfo = json.encode(taskData['bittorrent']);
    }
    
    // Parse URIs if available
    List<String>? uris;
    if (taskData.containsKey('uris') && taskData['uris'] is List) {
      uris = (taskData['uris'] as List).expand((uriList) {
        if (uriList is List) {
          return uriList.whereType<Map>().map((uri) => uri['uri'] as String? ?? '').where((s) => s.isNotEmpty).cast<String>();
        }
        return <String>[];
      }).toList();
    }
    
    // Parse error message if any
    String? errorMessage;
    if (taskData.containsKey('errorMessage')) {
      errorMessage = taskData['errorMessage'] as String?;
    }
    
    // Parse bitfield data
    String? bitfield;
    if (taskData.containsKey('bitfield')) {
      bitfield = taskData['bitfield'] as String?;
    }
    
    // If there's no file name, use gid as the name
    if (name.isEmpty) {
      name = id.substring(0, 8);
    }
    
    // Get download status from API status
    DownloadStatus status = getDownloadStatus(taskStatus);
    
    return DownloadTask(
      id: id,
      name: name,
      status: status,
      taskStatus: taskStatus,
      progress: progress,
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      size: size,
      completedSize: completedSize,
      isLocal: isLocal,
      instanceId: instanceId,
      connections: connections,
      dir: dir,
      // Extended detailed information
      totalLengthBytes: totalLengthBytes,
      completedLengthBytes: completedLengthBytes,
      downloadSpeedBytes: downloadSpeedBytes,
      uploadSpeedBytes: uploadSpeedBytes,
      files: files,
      bittorrentInfo: bittorrentInfo,
      uris: uris,
      errorMessage: errorMessage,
      bitfield: bitfield,
    );
  }

  // Get download status from API status string
  static DownloadStatus getDownloadStatus(String? apiStatus) {
    if (apiStatus == null) return DownloadStatus.waiting;
    
    switch (apiStatus) {
      case 'active':
        return DownloadStatus.active;
      case 'waiting':
      case 'paused':
        return DownloadStatus.waiting;
      case 'complete':
      case 'error':
      case 'removed':
        return DownloadStatus.stopped;
      default:
        return DownloadStatus.waiting;
    }
  }
}