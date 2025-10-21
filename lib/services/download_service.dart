import '../models/download_task.dart';
import '../models/enums/download_enums.dart';

// 下载服务类，负责处理下载相关的业务逻辑
class DownloadService {
  // 从活动实例获取并解析任务列表
  Future<List<DownloadTask>> getTasks(String instanceId) async {
    try {
      // 这里应该实现从aria2实例获取任务数据的逻辑
      // 目前返回模拟数据
      return _getMockTasks(instanceId);
    } catch (e) {
      print('获取任务列表失败: $e');
      return [];
    }
  }

  // 解析任务数据
  DownloadTask parseTask(Map<String, dynamic> taskData, String instanceId) {
    // 基础信息
    String gid = taskData['gid'] ?? '';
    String status = taskData['status'] ?? 'unknown';
    
    // 进度信息
    int completedLength = taskData['completedLength'] != null ? int.parse(taskData['completedLength']) : 0;
    int totalLength = taskData['totalLength'] != null ? int.parse(taskData['totalLength']) : 0;
    
    // 计算进度百分比
    double progress = totalLength > 0 ? (completedLength / totalLength) * 100 : 0.0;
    
    // 速度信息
    int downloadSpeed = taskData['downloadSpeed'] != null ? int.parse(taskData['downloadSpeed']) : 0;
    int uploadSpeed = taskData['uploadSpeed'] != null ? int.parse(taskData['uploadSpeed']) : 0;
    
    // 文件信息
    String name = taskData['bittorrent']?['info']?['name'] ?? taskData['files']?[0]?['path']?[0] ?? '未知文件名';
    String directory = taskData['dir'] ?? '';
    
    // 其他信息
    String errorMessage = taskData['errorMessage'] ?? '';
    String pieceLength = taskData['pieceLength'] ?? '0';
    String numPieces = taskData['numPieces'] ?? '0';
    String bitfield = taskData['bittorrent']?['info']?['bitfield'] ?? '';
    
    // 创建任务对象
    return DownloadTask(
      id: gid,
      name: name,
      status: status,
      progress: progress,
      completedLength: completedLength,
      totalLength: totalLength,
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      directory: directory,
      errorMessage: errorMessage,
      pieceLength: pieceLength,
      numPieces: numPieces,
      bitfield: bitfield,
      instanceId: instanceId,
      files: _parseFiles(taskData['files'] ?? []),
    );
  }

  // 解析文件列表
  List<DownloadFile> _parseFiles(List<dynamic> filesData) {
    return filesData.map((fileData) {
      String path = fileData['path'] is List ? fileData['path'].join('/') : fileData['path'] ?? '';
      int length = fileData['length'] != null ? int.parse(fileData['length']) : 0;
      int completedLength = fileData['completedLength'] != null ? int.parse(fileData['completedLength']) : 0;
      bool selected = fileData['selected'] == 1;
      
      return DownloadFile(
        path: path,
        length: length,
        completedLength: completedLength,
        selected: selected,
      );
    }).toList();
  }

  // 暂停任务
  Future<bool> pauseTask(String taskId, String instanceId) async {
    try {
      // 这里应该实现暂停任务的逻辑
      print('暂停任务: $taskId, 实例: $instanceId');
      return true;
    } catch (e) {
      print('暂停任务失败: $e');
      return false;
    }
  }

  // 继续任务
  Future<bool> resumeTask(String taskId, String instanceId) async {
    try {
      // 这里应该实现继续任务的逻辑
      print('继续任务: $taskId, 实例: $instanceId');
      return true;
    } catch (e) {
      print('继续任务失败: $e');
      return false;
    }
  }

  // 停止任务
  Future<bool> stopTask(String taskId, String instanceId) async {
    try {
      // 这里应该实现停止任务的逻辑
      print('停止任务: $taskId, 实例: $instanceId');
      return true;
    } catch (e) {
      print('停止任务失败: $e');
      return false;
    }
  }

  // 重试任务
  Future<bool> retryTask(String taskId, String instanceId) async {
    try {
      // 这里应该实现重试任务的逻辑
      print('重试任务: $taskId, 实例: $instanceId');
      return true;
    } catch (e) {
      print('重试任务失败: $e');
      return false;
    }
  }

  // 添加任务
  Future<bool> addTask(String uri, String directory, String taskType) async {
    try {
      // 这里应该实现添加任务的逻辑
      print('添加任务: $uri, 目录: $directory, 类型: $taskType');
      return true;
    } catch (e) {
      print('添加任务失败: $e');
      return false;
    }
  }

  // 打开下载目录
  Future<bool> openDownloadDirectory(String directory) async {
    try {
      // 这里应该实现打开下载目录的逻辑
      print('打开下载目录: $directory');
      return true;
    } catch (e) {
      print('打开下载目录失败: $e');
      return false;
    }
  }

  // 获取实例名称
  String getInstanceName(String instanceId) {
    // 这里应该从配置或缓存中获取实例名称
    // 目前返回ID作为名称
    return instanceId;
  }

  // 获取所有实例ID
  List<String> getAllInstanceIds() {
    // 这里应该从配置或缓存中获取所有实例ID
    // 目前返回模拟数据
    return ['instance1', 'instance2'];
  }

  // 根据筛选选项过滤任务
  List<DownloadTask> filterTasks(List<DownloadTask> tasks, FilterOption filterOption) {
    switch (filterOption) {
      case FilterOption.all:
        return tasks;
      case FilterOption.active:
        return tasks.where((task) => task.status == 'active').toList();
      case FilterOption.paused:
        return tasks.where((task) => task.status == 'paused').toList();
      case FilterOption.completed:
        return tasks.where((task) => task.status == 'complete').toList();
      case FilterOption.stopped:
        return tasks.where((task) => task.status == 'stopped').toList();
      case FilterOption.error:
        return tasks.where((task) => task.status == 'error').toList();
      default:
        return tasks;
    }
  }

  // 模拟任务数据（仅用于测试）
  List<DownloadTask> _getMockTasks(String instanceId) {
    return [
      DownloadTask(
        id: 'task1',
        name: 'sample1.mp4',
        status: 'active',
        progress: 45.5,
        completedLength: 455000000,
        totalLength: 1000000000,
        downloadSpeed: 1048576, // 1MB/s
        uploadSpeed: 102400, // 100KB/s
        directory: 'C:/Downloads',
        errorMessage: '',
        pieceLength: '1048576',
        numPieces: '954',
        bitfield: '0x12345678',
        instanceId: instanceId,
        files: [
          DownloadFile(
            path: 'sample1.mp4',
            length: 1000000000,
            completedLength: 455000000,
            selected: true,
          ),
        ],
      ),
      DownloadTask(
        id: 'task2',
        name: 'sample2.zip',
        status: 'paused',
        progress: 30.0,
        completedLength: 300000000,
        totalLength: 1000000000,
        downloadSpeed: 0,
        uploadSpeed: 0,
        directory: 'C:/Downloads',
        errorMessage: '',
        pieceLength: '1048576',
        numPieces: '954',
        bitfield: '0x1234',
        instanceId: instanceId,
        files: [
          DownloadFile(
            path: 'sample2.zip',
            length: 1000000000,
            completedLength: 300000000,
            selected: true,
          ),
        ],
      ),
      DownloadTask(
        id: 'task3',
        name: 'sample3.txt',
        status: 'complete',
        progress: 100.0,
        completedLength: 10240,
        totalLength: 10240,
        downloadSpeed: 0,
        uploadSpeed: 0,
        directory: 'C:/Downloads',
        errorMessage: '',
        pieceLength: '1024',
        numPieces: '10',
        bitfield: '0x3ff',
        instanceId: instanceId,
        files: [
          DownloadFile(
            path: 'sample3.txt',
            length: 10240,
            completedLength: 10240,
            selected: true,
          ),
        ],
      ),
      DownloadTask(
        id: 'task4',
        name: 'sample4.pdf',
        status: 'error',
        progress: 10.0,
        completedLength: 100000000,
        totalLength: 1000000000,
        downloadSpeed: 0,
        uploadSpeed: 0,
        directory: 'C:/Downloads',
        errorMessage: '连接失败，请检查网络设置',
        pieceLength: '1048576',
        numPieces: '954',
        bitfield: '0x1',
        instanceId: instanceId,
        files: [
          DownloadFile(
            path: 'sample4.pdf',
            length: 1000000000,
            completedLength: 100000000,
            selected: true,
          ),
        ],
      ),
    ];
  }
}