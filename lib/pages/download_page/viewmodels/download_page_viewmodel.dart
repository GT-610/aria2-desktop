import 'dart:async';
import 'package:flutter/material.dart';
import '../enums/download_status.dart';
import '../enums/category_type.dart';
import '../enums/filter_option.dart';
import '../models/download_task.dart';
import '../../services/instance_manager.dart';

class DownloadPageViewModel with ChangeNotifier {
  // Filter options
  FilterOption selectedFilter = FilterOption.all;
  CategoryType currentCategoryType = CategoryType.all;

  // Instance name mapping for displaying instance names
  Map<String, String> instanceNames = {};
  
  // Timer for periodically fetching task status
  Timer? refreshTimer;
  
  // Download task list
  List<DownloadTask> downloadTasks = [];
  
  // InstanceManager instance
  InstanceManager? instanceManager;

  // Initialize viewmodel
  void initialize(InstanceManager manager) {
    instanceManager = manager;
    loadInstanceNames();
    startPeriodicRefresh();
  }

  // Load instance names
  Future<void> loadInstanceNames() async {
    // Implementation will be added later
  }

  // Start periodic refresh
  void startPeriodicRefresh() {
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      refreshTasks();
    });
  }

  // Stop periodic refresh
  void stopPeriodicRefresh() {
    refreshTimer?.cancel();
    refreshTimer = null;
  }

  // Refresh all tasks
  Future<void> refreshTasks() async {
    // Implementation will be added later
  }

  // Parse task list
  List<DownloadTask> parseTasks(List tasks, DownloadStatus status, String instanceId, bool isLocal) {
    // Implementation will be added later
    return [];
  }

  // Parse single task data
  DownloadTask parseTask(Map<String, dynamic> taskData) {
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
      isLocal: false,
      instanceId: '',
    );
  }

  // Get filtered tasks
  List<DownloadTask> getFilteredTasks() {
    // Implementation will be added later
    return downloadTasks;
  }

  @override
  void dispose() {
    stopPeriodicRefresh();
    super.dispose();
  }
}