import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/instance_manager.dart';
import '../services/aria2_rpc_client.dart';
import '../models/aria2_instance.dart';
import '../models/global_stat.dart';

// Define download task status enum
enum DownloadStatus {
  active,   // Active
  waiting,  // Waiting
  stopped   // Stopped
}

// Define category type enum
enum CategoryType {
  all,      // All
  byStatus, // By status
  byType,   // By type
  byInstance // By instance
}

// Define filter option enum
enum FilterOption {
  all,      // All items
  active,   // Active status
  waiting,  // Waiting status
  stopped,  // Stopped status
  local,    // Local type
  remote,   // Remote type
  instance, // Instance filter (dynamic)
}

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
  });
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  FilterOption _selectedFilter = FilterOption.all;
  CategoryType _currentCategoryType = CategoryType.all; // 默认设置为'全部'

  // Instance name mapping for displaying instance names
  Map<String, String> _instanceNames = {};
  
  // Timer for periodically fetching task status
  Timer? _refreshTimer;
  
  // Download task list
  List<DownloadTask> _downloadTasks = [];
  
  // InstanceManager instance
  InstanceManager? instanceManager;

  @override
  void initState() {
    super.initState();
    // Load instance names and initialize
    _initialize();
    
    // Get InstanceManager instance through Provider
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    // Listen for changes in the instance manager and refresh the page when instance status changes
    instanceManager?.addListener(_handleInstanceChanges);
    
    // Start periodic refresh (every 1 second)
    _startPeriodicRefresh();
  }
  
  // Initialize
  Future<void> _initialize() async {
    // Get instance manager from Provider
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    await _loadInstanceNames(instanceManager!);
    await _refreshTasks();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for changes in the instance manager
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    instanceManager?.addListener(_handleInstanceChanges);
  }
  
  // Start periodic refresh
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _refreshTasks();
    });
  }
  
  // Stop periodic refresh
  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
  
  @override
  void dispose() {
    _stopPeriodicRefresh();
    // Remove listener to avoid memory leaks
    if (instanceManager != null) {
      instanceManager!.removeListener(_handleInstanceChanges);
    }
    super.dispose();
  }
  
  // Method to handle instance status changes
  void _handleInstanceChanges() {
    if (mounted && instanceManager != null) {
      setState(() {
        // When status changes, we don't need any special handling, setState will trigger UI rebuild
        // UI will re-render based on the latest instance status during rebuild
      });
      // When instance status changes, reload the task list
      _refreshTasks();
    }
  }
  
  // Refresh all tasks
  Future<void> _refreshTasks() async {
    try {
      List<DownloadTask> allTasks = [];
      
      // Get instance manager from Provider
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      
      // Only send requests to active instances, no longer loop through all instances
      final activeInstance = instanceManager.activeInstance;
      if (activeInstance != null) {
        // Check instance status, do not attempt to connect if not in connected state
        if (activeInstance.status == ConnectionStatus.connected) {
          try {
            // Create RPC client
            final client = Aria2RpcClient(activeInstance);
            
            // Send multicall request to get all tasks
            final response = await client.getTasksMulticall();
            
            // Parse response
            if (response.containsKey('result') && response['result'] is List) {
              final result = response['result'] as List;
              
              // Print debug information: structure and content of result
              print('result结构: $result');
              print('result长度: ${result.length}');
              
              // Parse active tasks - handle three-layer nested array structure [[[]], [[]], [[...]]]
              if (result.length > 0 && result[0] is List && (result[0] as List).isNotEmpty && (result[0] as List)[0] is List) {
                final activeTasks = (result[0] as List)[0] as List;
                print('活跃任务数量: ${activeTasks.length}');
                allTasks.addAll(_parseTasks(activeTasks, DownloadStatus.active, activeInstance.id, activeInstance.type == InstanceType.local));
              }
              
              // Parse waiting tasks
              if (result.length > 1 && result[1] is List && (result[1] as List).isNotEmpty && (result[1] as List)[0] is List) {
                final waitingTasks = (result[1] as List)[0] as List;
                print('等待任务数量: ${waitingTasks.length}');
                allTasks.addAll(_parseTasks(waitingTasks, DownloadStatus.waiting, activeInstance.id, activeInstance.type == InstanceType.local));
              }
              
              // Parse stopped tasks
              if (result.length > 2 && result[2] is List && (result[2] as List).isNotEmpty && (result[2] as List)[0] is List) {
                final stoppedTasks = (result[2] as List)[0] as List;
                print('已停止任务数量: ${stoppedTasks.length}');
                if (stoppedTasks.isNotEmpty) {
                  print('第一个已停止任务数据: ${stoppedTasks[0]}');
                }
                final parsedStoppedTasks = _parseTasks(stoppedTasks, DownloadStatus.stopped, activeInstance.id, activeInstance.type == InstanceType.local);
                print('解析后的已停止任务数量: ${parsedStoppedTasks.length}');
                allTasks.addAll(parsedStoppedTasks);
              }
            }
            
            // Close client
            client.close();
          } catch (e) {
            print('Failed to get tasks from instance ${activeInstance.name}: $e');
          }
        } else if (activeInstance.status == ConnectionStatus.connecting) {
          // 如果正在连接中，不重复尝试
        } else {
          // 如果实例未连接且不是正在连接中，不尝试连接
          // 避免自动连接行为
        }
      }
      
      // Update task list
      if (mounted) {
        setState(() {
          _downloadTasks = allTasks;
        });
        
        // 如果有任务详情对话框打开，通知其更新
        // 注意：由于我们使用StatefulBuilder，实际上StatefulBuilder会自动重建
        // 当主循环调用setState时，整个页面会重建，包括打开的对话框
      }
    } catch (e) {
      print('Failed to refresh tasks: $e');
    }
  }
  
  // Parse task list - now stores complete information in the model
  List<DownloadTask> _parseTasks(List tasks, DownloadStatus status, String instanceId, bool isLocal) {
    List<DownloadTask> parsedTasks = [];
    
    for (var taskData in tasks) {
      if (taskData is Map) {
        try {
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
          String size = _formatBytes(totalLengthBytes);
          String completedSize = _formatBytes(completedLengthBytes);
          String downloadSpeed = _formatBytes(downloadSpeedBytes) + '/s';
          String uploadSpeed = _formatBytes(uploadSpeedBytes) + '/s';
          
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
            ? int.tryParse(taskData['connections'] as String? ?? '') ?? null
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
          
          // If there's no file name, use gid as the name
          if (name.isEmpty) {
            name = id.substring(0, 8);
          }
          
          parsedTasks.add(DownloadTask(
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
            // We don't have exact start time from the API, so we'll leave it as null
            // and it can be set when needed
          ));
        } catch (e) {
          print('Failed to parse task: $e');
          continue;
        }
      }
    }
    
    return parsedTasks;
  }
  
  // Format byte size
  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = (bytes == 0 ? 0 : (log(bytes) / log(1024))).floor();
    i = i.clamp(0, suffixes.length - 1);
    
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
  
  // Calculate and format remaining time
  String _calculateRemainingTime(DownloadTask task) {
    // Only calculate remaining time for active tasks
    if (task.status != DownloadStatus.active) {
      return '-';
    }
    
    try {
      // Extract numeric part from download speed string (e.g., "1.2 MB/s" -> 1.2 MB)
      String speedStr = task.downloadSpeed;
      if (speedStr.contains('/s')) {
        speedStr = speedStr.replaceAll('/s', '').trim();
      }
      
      // Parse speed value
      double speedValue = 0;
      String speedUnit = '';
      
      // Match number and unit
      final speedMatch = RegExp(r'([\d.]+)\s*([BKMGT]B?)').firstMatch(speedStr);
      if (speedMatch != null && speedMatch.groupCount >= 2) {
        speedValue = double.tryParse(speedMatch.group(1)!) ?? 0;
        speedUnit = speedMatch.group(2)!;
        
        // Convert speed to bytes per second
        if (speedUnit.startsWith('KB')) {
          speedValue *= 1024;
        } else if (speedUnit.startsWith('MB')) {
          speedValue *= 1024 * 1024;
        } else if (speedUnit.startsWith('GB')) {
          speedValue *= 1024 * 1024 * 1024;
        } else if (speedUnit.startsWith('TB')) {
          speedValue *= 1024 * 1024 * 1024 * 1024;
        }
      }
      
      // If speed is 0 or invalid, return '未知'
      if (speedValue <= 0) {
        return '未知';
      }
      
      // Extract total size and completed size
      String totalSizeStr = task.size;
      String completedSizeStr = task.completedSize;
      
      // Parse total size
      double totalSize = 0;
      String totalUnit = '';
      
      final totalMatch = RegExp(r'([\d.]+)\s*([BKMGT]B?)').firstMatch(totalSizeStr);
      if (totalMatch != null && totalMatch.groupCount >= 2) {
        totalSize = double.tryParse(totalMatch.group(1)!) ?? 0;
        totalUnit = totalMatch.group(2)!;
        
        // Convert to bytes
        if (totalUnit.startsWith('KB')) {
          totalSize *= 1024;
        } else if (totalUnit.startsWith('MB')) {
          totalSize *= 1024 * 1024;
        } else if (totalUnit.startsWith('GB')) {
          totalSize *= 1024 * 1024 * 1024;
        } else if (totalUnit.startsWith('TB')) {
          totalSize *= 1024 * 1024 * 1024 * 1024;
        }
      }
      
      // Parse completed size
      double completedSize = 0;
      String completedUnit = '';
      
      final completedMatch = RegExp(r'([\d.]+)\s*([BKMGT]B?)').firstMatch(completedSizeStr);
      if (completedMatch != null && completedMatch.groupCount >= 2) {
        completedSize = double.tryParse(completedMatch.group(1)!) ?? 0;
        completedUnit = completedMatch.group(2)!;
        
        // Convert to bytes
        if (completedUnit.startsWith('KB')) {
          completedSize *= 1024;
        } else if (completedUnit.startsWith('MB')) {
          completedSize *= 1024 * 1024;
        } else if (completedUnit.startsWith('GB')) {
          completedSize *= 1024 * 1024 * 1024;
        } else if (completedUnit.startsWith('TB')) {
          completedSize *= 1024 * 1024 * 1024 * 1024;
        }
      }
      
      // Calculate remaining bytes
      double remainingBytes = totalSize - completedSize;
      
      // Calculate remaining time in seconds
      double remainingSeconds = remainingBytes / speedValue;
      
      // Format remaining time
      if (remainingSeconds < 60) {
        return '${remainingSeconds.ceil()}s';
      } else if (remainingSeconds < 3600) {
        int minutes = (remainingSeconds / 60).floor();
        int seconds = (remainingSeconds % 60).floor();
        return '${minutes}m ${seconds}s';
      } else {
        int hours = (remainingSeconds / 3600).floor();
        int minutes = ((remainingSeconds % 3600) / 60).floor();
        return '${hours}h ${minutes}m';
      }
    } catch (e) {
      // If any error occurs during calculation, return '未知'
      print('Error calculating remaining time: $e');
      return '未知';
    }
  }

  // Parse single task data - now compatible with extended model
  // This function is now primarily used as a fallback when task isn't found in the main list
  DownloadTask _parseTask(Map<String, dynamic> taskData) {
    // Parse raw bytes data first for accurate calculations and storage
    final totalLengthBytes = int.tryParse(taskData['totalLength'] as String? ?? '0') ?? 0;
    final completedLengthBytes = int.tryParse(taskData['completedLength'] as String? ?? '0') ?? 0;
    final downloadSpeedBytes = int.tryParse(taskData['downloadSpeed'] as String? ?? '0') ?? 0;
    final uploadSpeedBytes = int.tryParse(taskData['uploadSpeed'] as String? ?? '0') ?? 0;
    
    // Parse basic info
    final id = taskData['gid'] as String? ?? '';
    
    // Parse status
    DownloadStatus status = DownloadStatus.waiting;
    String? taskStatus = taskData['status'] as String?;
    
    if (taskStatus != null) {
      switch (taskStatus) {
        case 'active':
          status = DownloadStatus.active;
          break;
        case 'waiting':
        case 'paused':
          status = DownloadStatus.waiting;
          break;
        case 'complete':
        case 'error':
        case 'removed':
          status = DownloadStatus.stopped;
          break;
      }
    }
    
    // Calculate progress
    double progress = totalLengthBytes > 0 ? completedLengthBytes / totalLengthBytes : 0.0;
    
    // Format display values
    String size = _formatBytes(totalLengthBytes);
    String completedSize = _formatBytes(completedLengthBytes);
    String downloadSpeed = _formatBytes(downloadSpeedBytes) + '/s';
    String uploadSpeed = _formatBytes(uploadSpeedBytes) + '/s';
    
    // Get file name and store complete files info
    String name = '未知任务';
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
    
    // Parse additional details
    int? connections = taskData.containsKey('connections') 
      ? int.tryParse(taskData['connections'] as String? ?? '') ?? null
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
    
    // Return parsed task object with all extended fields
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
      isLocal: true, // Default value, will be updated based on instance
      instanceId: '', // Default value, will be updated based on instance
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
    );
  }

  // 存储当前打开的任务详情对话框中的任务ID
  String? _openedTaskDetailsId;
  
  // 更新任务详情的回调函数
  void _updateTaskDetails() {
    if (_openedTaskDetailsId != null) {
      // 当主循环刷新任务列表后，我们可以在这里添加通知对话框更新的逻辑
      // 由于我们使用Provider和StatefulBuilder，实际上不需要显式通知
      // 对话框会通过StatefulBuilder自动获取最新数据
    }
  }
  
  // Show task details dialog using main loop data - now displays extended information
  void _showTaskDetails(BuildContext context, DownloadTask task) {
    // 设置当前打开的任务ID
    _openedTaskDetailsId = task.id;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 从主循环的下载任务列表中查找当前任务的最新数据
            DownloadTask getLatestTaskData() {
              // 优先从主循环的任务列表中查找
              final taskFromList = _downloadTasks.firstWhere(
                (t) => t.id == task.id,
                orElse: () => task, // 如果找不到，使用传入的task作为默认值
              );
              return taskFromList;
            }
            
            // 创建一个每分钟刷新一次的定时器（仅作为备份，主循环会更频繁地更新）
            // 这样即使主循环数据有问题，详情页也能更新
            Timer? backupTimer;
            backupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
              if (context.mounted) {
                setState(() {
                  // 触发重建，从主循环获取最新数据
                });
              }
            });
            
            // 获取最新的任务数据
            final currentTask = getLatestTaskData();

            return DefaultTabController(
              length: 3,
              initialIndex: 0, // 默认选中第一个标签页（总览）
              child: AlertDialog(
                title: Text('任务详情 - ${currentTask.name}'),
                content: SizedBox(
                  width: 600,
                  height: 450,
                  child: Column(
                    children: [
                      // 标签栏
                      TabBar(
                        tabs: const [
                          Tab(text: '总览'),
                          Tab(text: '文件信息'),
                          Tab(text: '连接信息'),
                        ],
                        indicatorSize: TabBarIndicatorSize.tab,
                      ),
                      // 标签页内容
                      Expanded(
                        child: TabBarView(
                          children: [
                            // 总览标签页 - 显示扩展的详细信息
                            SingleChildScrollView(
                              padding: EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 基本信息
                                  Text('任务ID: ${currentTask.id}'),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('任务状态: '),
                                      Text(
                                        _getStatusInfo(currentTask, Theme.of(context).colorScheme).$1,
                                        style: TextStyle(color: _getStatusInfo(currentTask, Theme.of(context).colorScheme).$2),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text('任务大小: ${currentTask.size} (${currentTask.totalLengthBytes} 字节)'),
                                  SizedBox(height: 8),
                                  Text('已下载: ${currentTask.completedSize} (${currentTask.completedLengthBytes} 字节)'),
                                  SizedBox(height: 8),
                                  Text('进度: ${(currentTask.progress * 100).toStringAsFixed(2)}%'),
                                  SizedBox(height: 12),
                                  // 速度信息
                                  Text('下载速度: ${currentTask.downloadSpeed} (${currentTask.downloadSpeedBytes} 字节/秒)'),
                                  SizedBox(height: 8),
                                  Text('上传速度: ${currentTask.uploadSpeed} (${currentTask.uploadSpeedBytes} 字节/秒)'),
                                  SizedBox(height: 12),
                                  // 其他信息
                                  Text('连接数: ${currentTask.connections ?? '--'}'),
                                  SizedBox(height: 8),
                                  Text('下载路径: ${currentTask.dir ?? '--'}'),
                                  SizedBox(height: 8),
                                  // 显示错误信息（如果有）
                                  if (currentTask.errorMessage != null && currentTask.errorMessage!.isNotEmpty) 
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('错误信息: ${currentTask.errorMessage}', style: TextStyle(color: Colors.red)),
                                        SizedBox(height: 8),
                                      ],
                                    ),
                                  // 计算并显示剩余时间
                                  if (currentTask.status == DownloadStatus.active && currentTask.downloadSpeedBytes > 0)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('剩余时间: ${_calculateRemainingTime(currentTask)}'),
                                        SizedBox(height: 8),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            
                            // 文件信息标签页 - 显示从主循环获取的文件列表
                            SingleChildScrollView(
                              padding: EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('文件列表:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  if (currentTask.files != null && currentTask.files!.isNotEmpty) 
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: currentTask.files!.length,
                                      itemBuilder: (context, index) {
                                        final file = currentTask.files![index];
                                        final filePath = file['path'] as String? ?? '未知路径';
                                        final fileName = filePath.split('/').last.split('\\').last;
                                        final fileSize = _formatBytes(int.tryParse(file['length'] as String? ?? '0') ?? 0);
                                        final completedSize = _formatBytes(int.tryParse(file['completedLength'] as String? ?? '0') ?? 0);
                                        final selected = (file['selected'] as String? ?? 'true') == 'true';
                                        
                                        return Container(
                                          padding: EdgeInsets.symmetric(vertical: 4),
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(fileName, style: TextStyle(fontWeight: selected ? FontWeight.normal : FontWeight.w300)),
                                              Row(
                                                children: [
                                                  Text('$completedSize / $fileSize'),
                                                  if (!selected) Text(' (未选择)', style: TextStyle(color: Colors.grey)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  else
                                    Text('无文件信息'),
                                ],
                              ),
                            ),
                            
                            // 连接信息标签页 - 显示从主循环获取的URI信息
                            SingleChildScrollView(
                              padding: EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('下载链接:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  if (currentTask.uris != null && currentTask.uris!.isNotEmpty) 
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: currentTask.uris!.length,
                                      itemBuilder: (context, index) {
                                        final uri = currentTask.uris![index];
                                        return Container(
                                          padding: EdgeInsets.symmetric(vertical: 4),
                                          decoration: BoxDecoration(
                                            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                          ),
                                          child: Text(uri, style: TextStyle(fontSize: 12, color: Colors.blue)),
                                        );
                                      },
                                    )
                                  else
                                    Text('无链接信息'),
                                  SizedBox(height: 16),
                                  // 显示种子信息指示
                                  if (currentTask.bittorrentInfo != null) 
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('种子信息:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        SizedBox(height: 4),
                                        Text('此任务为种子下载，包含种子元数据'),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      backupTimer?.cancel();
                      _openedTaskDetailsId = null; // 清除当前打开的任务ID
                      Navigator.of(context).pop();
                    },
                    child: Text('关闭'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // 对话框关闭时清除状态
      _openedTaskDetailsId = null;
    });
  }
  
  // Load instance names
  Future<void> _loadInstanceNames(InstanceManager instanceManager) async {
    try {
      // Get all instances
      final instances = instanceManager.instances;
      
      // Build mapping from instance ID to name
      final Map<String, String> instanceMap = {};
      for (final instance in instances) {
        instanceMap[instance.id] = instance.name;
      }
      
      // Update state
      if (mounted) {
        setState(() {
          _instanceNames = instanceMap;
        });
      }
    } catch (e) {
      print('Failed to load instance names: $e');
      // Notify user when error occurs
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load instance names: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
        // Keep _instanceNames empty to avoid displaying incorrect instance information
      }
    }
  }
  
  // Called when instance list changes
  void _onInstancesChanged() {
    if (mounted) {
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      _loadInstanceNames(instanceManager);
      _refreshTasks();
    }
  }
  
  // Get instance name by ID
  String _getInstanceName(String instanceId) {
    return _instanceNames[instanceId] ?? '未知实例';
  }
  
  // Get all instance IDs list
  List<String> _getAllInstanceIds() {
    // 从任务中提取所有唯一的实例ID
    return _downloadTasks.map((task) => task.instanceId).toSet().toList();
  }

  // Get status text and color
  (String, Color) _getStatusInfo(DownloadTask task, ColorScheme colorScheme) {
    // 检查是否为暂停中任务
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return ('已暂停', colorScheme.tertiary);
    }
    
    switch (task.status) {
      case DownloadStatus.active:
        return ('下载中', colorScheme.primary);
      case DownloadStatus.waiting:
        return ('等待中', colorScheme.secondary);
      case DownloadStatus.stopped:
        return ('已停止', colorScheme.errorContainer);
    }
  }

  // Get status icon
  Icon _getStatusIcon(DownloadTask task, Color color) {
    // 检查是否为暂停中任务
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return Icon(Icons.pause, color: color);
    }
    
    switch (task.status) {
      case DownloadStatus.active:
        return Icon(Icons.file_download, color: color);
      case DownloadStatus.waiting:
        return Icon(Icons.schedule, color: color);
      case DownloadStatus.stopped:
        return Icon(Icons.pause_circle, color: color);
    }
  }

  // Store currently selected instance ID
  String? _selectedInstanceId;
  
  // Filter tasks based on selected criteria
  List<DownloadTask> _filterTasks() {
    List<DownloadTask> filtered = _downloadTasks;
    
    // 如果是按实例筛选，使用_selectedInstanceId
    if (_currentCategoryType == CategoryType.byInstance && _selectedInstanceId != null) {
      filtered = filtered.where((task) => task.instanceId == _selectedInstanceId).toList();
    } else {
      // 其他分类使用_selectedFilter
      switch (_selectedFilter) {
        case FilterOption.all:
          // 全部任务，不过滤
          break;
        case FilterOption.active:
          filtered = filtered.where((task) => task.status == DownloadStatus.active).toList();
          break;
        case FilterOption.waiting:
          filtered = filtered.where((task) => task.status == DownloadStatus.waiting).toList();
          break;
        case FilterOption.stopped:
          filtered = filtered.where((task) => task.status == DownloadStatus.stopped).toList();
          break;
        case FilterOption.local:
          filtered = filtered.where((task) => task.isLocal == true).toList();
          break;
        case FilterOption.remote:
          filtered = filtered.where((task) => task.isLocal == false).toList();
          break;
        case FilterOption.instance:
          // 实例筛选已经在上面处理
          break;
      }
    }
    
    return filtered;
  }
  
  // Get display text for filter option
  String _getFilterText(FilterOption filter) {
    switch (filter) {
      case FilterOption.all:
        return '全部';
      case FilterOption.active:
        return '下载中';
      case FilterOption.waiting:
        return '等待中';
      case FilterOption.stopped:
        return '已停止';
      case FilterOption.local:
        return '本地';
      case FilterOption.remote:
        return '远程';
      case FilterOption.instance:
        return '实例';
    }
  }
  
  // Get color for filter option
  Color _getFilterColor(FilterOption filter, ColorScheme colorScheme) {
    switch (filter) {
      case FilterOption.all:
        return colorScheme.primaryContainer;
      case FilterOption.active:
        return colorScheme.primary;
      case FilterOption.waiting:
        return colorScheme.secondary;
      case FilterOption.stopped:
        return colorScheme.errorContainer;
      case FilterOption.local:
        return colorScheme.primary;
      case FilterOption.remote:
        return colorScheme.secondary;
      case FilterOption.instance:
        return colorScheme.tertiary;
    }
  }
  
  // Show category selection dialog
  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        
        return AlertDialog(
          title: const Text('选择分类方式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // All option
              _buildDialogOption(
                context,
                '全部',
                onTap: () {
                  setState(() {
                    _selectedFilter = FilterOption.all;
                    _currentCategoryType = CategoryType.all;
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By status
              _buildDialogOption(
                context,
                '按状态',
                onTap: () {
                  setState(() {
                    _currentCategoryType = CategoryType.byStatus;
                    _selectedFilter = FilterOption.active; // Select the first option by default
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By type
              _buildDialogOption(
                context,
                '按类型',
                onTap: () {
                  setState(() {
                    _currentCategoryType = CategoryType.byType;
                    _selectedFilter = FilterOption.local; // Select first option by default
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By instance
              _buildDialogOption(
                context,
                '按实例',
                onTap: () {
                  setState(() {
                    _currentCategoryType = CategoryType.byInstance;
                    _selectedInstanceId = null; // Reset selected instance
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Build dialog option
  Widget _buildDialogOption(BuildContext context, String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
  
  // Build filter selector
  Widget _buildFilterSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.surfaceVariant)),
      ),
      child: Row(
        children: [
          // Category button - always show this for switching categories
          FilledButton.tonal(
            onPressed: _showCategoryDialog,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(_getCurrentCategoryText()),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          // Only show filter chips when not in 'all' category
          if (_currentCategoryType != CategoryType.all) 
            const SizedBox(width: 12),
          // Dynamic filter chips based on selected category - only show when not in 'all' category
          if (_currentCategoryType != CategoryType.all) 
            // Special handling for instance category
            if (_currentCategoryType == CategoryType.byInstance)
              ..._getInstanceFilterOptions().map((instanceId) {
                final isSelected = _selectedInstanceId == instanceId;
                final instanceColor = colorScheme.tertiary;
                
                return Row(
                  children: [
                    FilterChip(
                      label: Text(
                        _getInstanceName(instanceId),
                        style: TextStyle(
                          color: instanceColor,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedInstanceId = selected ? instanceId : null;
                        });
                      },
                      selectedColor: instanceColor.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              }).toList()
            else
              ..._getFilterOptionsForCurrentCategory().map((option) {
                final isSelected = _selectedFilter == option;
                final filterColor = _getFilterColor(option, colorScheme);
                
                return Row(
                  children: [
                    FilterChip(
                      label: Text(
                        _getFilterText(option),
                        style: TextStyle(
                          color: filterColor,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedFilter = option;
                          });
                        }
                      },
                      selectedColor: filterColor.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              }).toList(),
        ],
      ),
    );
  }
  
  // Get current category display text
  String _getCurrentCategoryText() {
    switch (_currentCategoryType) {
      case CategoryType.all:
        return '全部';
      case CategoryType.byStatus:
        return '按状态';
      case CategoryType.byType:
        return '按类型';
      case CategoryType.byInstance:
        return '按实例';
      default:
        return '分类';
    }
  }
  
  // Get instance ID list as filter options
  List<String> _getInstanceFilterOptions() {
    return _getAllInstanceIds();
  }
  
  // Get filter options based on current category
  List<FilterOption> _getFilterOptionsForCurrentCategory() {
    switch (_currentCategoryType) {
      case CategoryType.byStatus:
        return [FilterOption.active, FilterOption.waiting, FilterOption.stopped];
      case CategoryType.byType:
        return [FilterOption.local, FilterOption.remote];
      case CategoryType.byInstance:
        // For instance category, we will handle it separately in UI
        return [FilterOption.instance];
      default:
        return [];
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: Column(
        children: [
          // Task action toolbar - Material You style
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.surfaceVariant)),
            ),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    _showAddTaskDialog(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加任务'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.pause),
                  label: const Text('暂停'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('继续'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.delete),
                  label: const Text('删除'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton.outlined(
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filter selector
          _buildFilterSelector(colorScheme),
          // Task list - Material You style
          Expanded(
            child: _buildTaskList(theme, colorScheme),
          ),
        ],
      ),
    );
  }

  // Build task list
  Widget _buildTaskList(ThemeData theme, ColorScheme colorScheme) {
    final tasks = _filterTasks();
    
    // Check if there are any connected instances
    final hasConnectedInstances = instanceManager?.instances.any((instance) => 
      instance.status == ConnectionStatus.connected
    ) ?? false;
    
    // If no connected instances, show special prompt
    if (!hasConnectedInstances) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            SizedBox(height: 16),
            Text('没有正在连接的实例，快去连接实例吧', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }
    
    // If there are connected instances but no tasks, show 'no tasks' message
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            SizedBox(height: 16),
            Text('暂无任务', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final (statusText, statusColor) = _getStatusInfo(task, colorScheme);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          surfaceTintColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _showTaskDetails(context, task);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Task name and status icon
                    Row(
                      children: [
                        _getStatusIcon(task, statusColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            task.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Download and upload speed display
                        if (task.status == DownloadStatus.active)
                          Row(
                            children: [
                              // Upload speed
                              Container(
                                margin: EdgeInsets.only(right: 8),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.upload, size: 12, color: colorScheme.secondary),
                                    SizedBox(width: 4),
                                    Text(
                                      task.uploadSpeed,
                                      style: TextStyle(
                                        color: colorScheme.secondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Download speed
                              Container(
                                margin: EdgeInsets.only(right: 8),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.download, size: 12, color: colorScheme.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      task.downloadSpeed,
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        // Status label
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Progress bar (shown for all statuses with slight style variation for non-active)
                    Stack(
                      children: [
                        LinearProgressIndicator(
                          value: task.progress,
                          borderRadius: BorderRadius.circular(10),
                          minHeight: 6,
                          backgroundColor: colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            // 暂停中任务使用黄色显示进度条
                            (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') 
                              ? colorScheme.tertiary 
                              : (task.status == DownloadStatus.active ? statusColor : statusColor.withOpacity(0.6)),
                          ),
                        ),
                        // Only show progress text for non-active status
                        if (task.status != DownloadStatus.active && task.progress > 0)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                '${(task.progress * 100).toInt()}%',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Task details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // File size info and instance name
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Instance name
                            Container(
                              margin: EdgeInsets.only(bottom: 2),
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getInstanceName(task.instanceId),
                                style: TextStyle(
                                  color: colorScheme.tertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Size info with remaining time
                            Text(
                              '${task.completedSize} / ${task.size} (${_calculateRemainingTime(task)})',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        // Action buttons - Dynamic based on task status
                        Row(
                          children: [
                            if (task.status == DownloadStatus.active) ...[
                              // Pause button
                              Tooltip(
                                message: '暂停',
                                child: IconButton(
                                  icon: const Icon(Icons.pause),
                                  onPressed: () async {
                                    print('Pause task: ${task.id}');
                                    try {
                                      // Get instance manager and active instance
                                      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
                                      final activeInstance = instanceManager.activeInstance;
                                      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                                        final client = Aria2RpcClient(activeInstance);
                                        await client.pauseTask(task.id);
                                        // Immediately refresh tasks after successful request
                                        await _refreshTasks();
                                        // Reset refresh timer
                                        _stopPeriodicRefresh();
                                        _startPeriodicRefresh();
                                      }
                                    } catch (e) {
                                      print('Error pausing task: $e');
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                              SizedBox(width: 8), // Add spacing between buttons
                              // Stop button
                              Tooltip(
                                message: '停止',
                                child: IconButton(
                                  icon: const Icon(Icons.stop),
                                  onPressed: () async {
                                    print('Stop task: ${task.id}');
                                    try {
                                      // Get instance manager and active instance
                                      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
                                      final activeInstance = instanceManager.activeInstance;
                                      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                                        final client = Aria2RpcClient(activeInstance);
                                        await client.removeTask(task.id);
                                        // Immediately refresh tasks after successful request
                                        await _refreshTasks();
                                        // Reset refresh timer
                                        _stopPeriodicRefresh();
                                        _startPeriodicRefresh();
                                      }
                                    } catch (e) {
                                      print('Error stopping task: $e');
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                            ] else if (task.status == DownloadStatus.waiting) ...[
                              // Resume button
                              Tooltip(
                                message: '继续',
                                child: IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () async {
                                    print('Resume task: ${task.id}');
                                    try {
                                      // Get instance manager and active instance
                                      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
                                      final activeInstance = instanceManager.activeInstance;
                                      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                                        final client = Aria2RpcClient(activeInstance);
                                        await client.unpauseTask(task.id);
                                        // Immediately refresh tasks after successful request
                                        await _refreshTasks();
                                        // Reset refresh timer
                                        _stopPeriodicRefresh();
                                        _startPeriodicRefresh();
                                      }
                                    } catch (e) {
                                      print('Error resuming task: $e');
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                              SizedBox(width: 8), // Add spacing between buttons
                              // Stop button
                              Tooltip(
                                message: '停止',
                                child: IconButton(
                                  icon: const Icon(Icons.stop),
                                  onPressed: () async {
                                    print('Stop task: ${task.id}');
                                    try {
                                      // Get instance manager and active instance
                                      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
                                      final activeInstance = instanceManager.activeInstance;
                                      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                                        final client = Aria2RpcClient(activeInstance);
                                        await client.removeTask(task.id);
                                        // Immediately refresh tasks after successful request
                                        await _refreshTasks();
                                        // Reset refresh timer
                                        _stopPeriodicRefresh();
                                        _startPeriodicRefresh();
                                      }
                                    } catch (e) {
                                      print('Error stopping task: $e');
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                            ] else if (task.status == DownloadStatus.stopped) ...[
                              // Retry button
                              Tooltip(
                                message: '重试',
                                child: IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    print('Retry task: ${task.id}');
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                            ],
                            SizedBox(width: 8), // Add spacing between buttons
                            // Open directory button - Show for all statuses
                            Tooltip(
                              message: '打开下载目录',
                              child: IconButton(
                                icon: const Icon(Icons.folder_open),
                                onPressed: () {
                                  print('Open directory for task: ${task.id}');
                                },
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 显示添加任务对话框
  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        // 使用DefaultTabController来简化TabController的管理
        return DefaultTabController(
          length: 3,
          initialIndex: 0,
          child: AlertDialog(
            title: const Text('添加任务'),
            content: SizedBox(
              width: 500,
              height: 450,
              child: Column(
                children: [
                  // 选项卡
                  const TabBar(
                    tabs: [
                      Tab(text: 'URI'),
                      Tab(text: '种子'),
                      Tab(text: 'Metalink'),
                    ],
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                  // 选项卡内容
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: TabBarView(
                            children: [
                              // URI 选项卡内容
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    TextField(
                                      decoration: const InputDecoration(
                                        labelText: 'URL或磁力链接',
                                        hintText: '请输入下载链接...',
                                        border: OutlineInputBorder(),
                                      ),
                                      maxLines: 3,
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () {
                                        // TODO: 实现从剪贴板粘贴功能
                                      },
                                      child: const Text('从剪贴板粘贴'),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('支持HTTP/HTTPS、FTP、SFTP、磁力链接等'),
                                  ],
                                ),
                              ),
                              // 种子 选项卡内容
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.file_open, size: 64),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: () {
                                        // TODO: 实现选择种子文件功能
                                      },
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('选择种子文件'),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('支持.torrent格式的种子文件'),
                                  ],
                                ),
                              ),
                              // Metalink 选项卡内容
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.file_open, size: 64),
                                    const SizedBox(height: 16),
                                    TextButton.icon(
                                      onPressed: () {
                                        // TODO: 实现选择Metalink文件功能
                                      },
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('选择Metalink文件'),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('支持.metalink格式的文件'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 分隔线
                        const Divider(),
                        // 公共区域 - 不受选项卡影响
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 保存位置
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: const InputDecoration(
                                        labelText: '保存位置',
                                        hintText: '默认下载目录',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      // TODO: 实现选择保存位置功能
                                    },
                                    child: const Icon(Icons.folder_open),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // 高级选项开关
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('显示高级选项'),
                                  Switch(
                                    value: false,
                                    onChanged: (bool value) {
                                      // TODO: 实现高级选项显示/隐藏逻辑
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  // TODO: 根据当前选中的选项卡实现添加任务功能
                  Navigator.of(context).pop();
                },
                child: const Text('确认'),
              ),
            ],
          ),
        );
      },
    );
  }
}