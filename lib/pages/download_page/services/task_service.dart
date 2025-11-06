import '../models/download_task.dart';
import '../enums/download_status.dart';

// Abstract service interface for download task operations
abstract class TaskService {
  // Get all active tasks
  Future<List<DownloadTask>> getActiveTasks(String instanceId, bool isLocal);
  
  // Get all waiting tasks
  Future<List<DownloadTask>> getWaitingTasks(String instanceId, bool isLocal);
  
  // Get all stopped tasks
  Future<List<DownloadTask>> getStoppedTasks(String instanceId, bool isLocal);
  
  // Start a task
  Future<bool> startTask(String taskId, String instanceId);
  
  // Pause a task
  Future<bool> pauseTask(String taskId, String instanceId);
  
  // Remove a task
  Future<bool> removeTask(String taskId, String instanceId, bool deleteFiles);
  
  // Get task details
  Future<DownloadTask?> getTaskDetails(String taskId, String instanceId);
  
  // Get task status
  Future<DownloadStatus> getTaskStatus(String taskId, String instanceId);
}