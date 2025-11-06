import '../enums/download_status.dart';
import '../models/download_task.dart';

// Utility class for parsing task data from RPC responses
class TaskParser {
  // Parse a list of tasks
  static List<DownloadTask> parseTasks(List tasks, DownloadStatus status, String instanceId, bool isLocal) {
    // Implementation will be added later
    return [];
  }

  // Parse a single task
  static DownloadTask parseTask(Map<String, dynamic> taskData, String instanceId, bool isLocal) {
    // Implementation will be added later
    return DownloadTask(
      id: '',
      name: '',
      status: DownloadStatus.waiting,
      progress: 0,
      downloadSpeed: '',
      uploadSpeed: '',
      size: '',
      completedSize: '',
      isLocal: isLocal,
      instanceId: instanceId,
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