// Enum definitions for download page functionality

/// Define download task status enum
enum DownloadStatus { active, waiting, stopped }

/// Define category type enum
enum CategoryType { all, byStatus, byType, byInstance }

/// Define filter option enum
enum FilterOption { all, active, waiting, stopped, local, remote, instance }

/// Define task sort option enum
enum TaskSortOption { name, progress, size, speed, instance }
