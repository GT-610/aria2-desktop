// 下载任务状态枚举
enum DownloadStatus {
  active,    // 下载中
  waiting,   // 等待中
  stopped,   // 已停止
}

// 分类类型枚举
enum CategoryType {
  all,           // 全部
  byStatus,      // 按状态
  byType,        // 按类型
  byInstance,    // 按实例
}

// 筛选选项枚举
enum FilterOption {
  all,         // 全部
  active,      // 下载中
  waiting,     // 等待中
  stopped,     // 已停止
  local,       // 本地
  remote,      // 远程
  instance,    // 实例
}