// Enum definitions for download page functionality

/// Aria2 API status strings (see aria2 RPC documentation).
const String aria2StatusPaused = 'paused';
const String aria2StatusComplete = 'complete';
const String aria2StatusError = 'error';

/// Define download task status enum
enum DownloadStatus { active, waiting, stopped }

/// Define category type enum
enum CategoryType { all, byStatus, byType, byInstance }

/// Define filter option enum
enum FilterOption { all, active, waiting, stopped, local, remote, instance }

/// Define task sort option enum
enum TaskSortOption { name, progress, size, speed, instance }
