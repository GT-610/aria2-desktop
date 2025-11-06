// Enum definitions for download page functionality

/// Define download task status enum
enum DownloadStatus {
  active,   // Active
  waiting,  // Waiting
  stopped   // Stopped
}

/// Define category type enum
enum CategoryType {
  all,      // All
  byStatus, // By status
  byType,   // By type
  byInstance // By instance
}

/// Define filter option enum
enum FilterOption {
  all,      // All items
  active,   // Active status
  waiting,  // Waiting status
  stopped,  // Stopped status
  local,    // Local type
  remote,   // Remote type
  instance, // Instance filter (dynamic)
}