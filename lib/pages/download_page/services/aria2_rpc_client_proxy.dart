import 'package:aria2/aria2.dart';
import '../models/download_task.dart';
import '../enums/download_status.dart';
import '../utils/task_parser.dart';

// Proxy service for interacting with Aria2 RPC client
class Aria2RpcClientProxy implements TaskService {
  final Aria2RpcClient _client;
  
  Aria2RpcClientProxy(this._client);

  @override
  Future<List<DownloadTask>> getActiveTasks(String instanceId, bool isLocal) async {
    // Implementation will be added later
    return [];
  }

  @override
  Future<List<DownloadTask>> getWaitingTasks(String instanceId, bool isLocal) async {
    // Implementation will be added later
    return [];
  }

  @override
  Future<List<DownloadTask>> getStoppedTasks(String instanceId, bool isLocal) async {
    // Implementation will be added later
    return [];
  }

  @override
  Future<bool> startTask(String taskId, String instanceId) async {
    // Implementation will be added later
    return false;
  }

  @override
  Future<bool> pauseTask(String taskId, String instanceId) async {
    // Implementation will be added later
    return false;
  }

  @override
  Future<bool> removeTask(String taskId, String instanceId, bool deleteFiles) async {
    // Implementation will be added later
    return false;
  }

  @override
  Future<DownloadTask?> getTaskDetails(String taskId, String instanceId) async {
    // Implementation will be added later
    return null;
  }

  @override
  Future<DownloadStatus> getTaskStatus(String taskId, String instanceId) async {
    // Implementation will be added later
    return DownloadStatus.waiting;
  }
}