import 'package:flutter/material.dart';
import '../../models/download_task.dart';
import '../../utils/format_utils.dart';

// 下载任务项组件
class DownloadTaskItem extends StatelessWidget {
  final DownloadTask task;
  final bool isExpanded;
  final Function()? onToggleExpand;
  final Function()? onPause;
  final Function()? onResume;
  final Function()? onStop;
  final Function()? onRetry;
  final Function()? onOpenDirectory;
  final Function()? onDetails;

  const DownloadTaskItem({
    super.key,
    required this.task,
    required this.isExpanded,
    this.onToggleExpand,
    this.onPause,
    this.onResume,
    this.onStop,
    this.onRetry,
    this.onOpenDirectory,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: InkWell(
        onTap: onToggleExpand,
        child: Column(
          children: [
            // 任务基本信息（始终可见）
            _buildTaskSummary(context),
            // 展开的详细信息
            if (isExpanded)
              _buildExpandedDetails(context),
          ],
        ),
      ),
    );
  }

  // 任务摘要信息
  Widget _buildTaskSummary(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态图标
          _getStatusIcon(task.status),
          const SizedBox(width: 12),
          // 主要信息区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        task.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (task.status == 'active')
                      Text(
                        '${task.progress.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _getStatusText(task.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(task.status),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (task.instanceId.isNotEmpty)
                      Text(
                        '实例: ${task.instanceId}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // 进度条
                if (task.status == 'active')
                  LinearProgressIndicator(
                    value: task.progress / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(task.status)),
                    minHeight: 4,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 展开的详细信息
  Widget _buildExpandedDetails(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 进度和大小信息
          if (task.status == 'active' || task.status == 'paused')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已下载: ${formatBytes(task.completedLength)} / ${formatBytes(task.totalLength)}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '剩余时间: ${_formatRemainingTime(task)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          // 速度信息
          if (task.status == 'active')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '下载速度: ${formatBytes(task.downloadSpeed)}/s',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  '上传速度: ${formatBytes(task.uploadSpeed)}/s',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          // 错误信息
          if (task.errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                '错误: ${task.errorMessage}',
                style: const TextStyle(fontSize: 12, color: Colors.red),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          // 操作按钮
          _buildActionButtons(context),
        ],
      ),
    );
  }

  // 操作按钮
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 打开目录按钮
          TextButton(
            onPressed: onOpenDirectory,
            child: const Text('打开目录'),
          ),
          const SizedBox(width: 4),
          // 详情按钮
          TextButton(
            onPressed: onDetails,
            child: const Text('详情'),
          ),
          const SizedBox(width: 4),
          // 根据状态显示不同的操作按钮
          if (task.status == 'active')
            TextButton(
              onPressed: onPause,
              child: const Text('暂停'),
            ),
          if (task.status == 'paused')
            TextButton(
              onPressed: onResume,
              child: const Text('继续'),
            ),
          if (task.status == 'paused' || task.status == 'active')
            TextButton(
              onPressed: onStop,
              child: const Text('停止'),
            ),
          if (task.status == 'error')
            TextButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }

  // 获取状态图标
  Widget _getStatusIcon(String status) {
    Color iconColor = _getStatusColor(status);
    IconData iconData;

    switch (status) {
      case 'active':
        iconData = Icons.download;
        break;
      case 'paused':
        iconData = Icons.pause_circle;
        break;
      case 'stopped':
        iconData = Icons.stop_circle;
        break;
      case 'complete':
        iconData = Icons.check_circle;
        break;
      case 'error':
        iconData = Icons.error;
        break;
      default:
        iconData = Icons.info;
    }

    return Icon(iconData, color: iconColor, size: 24);
  }

  // 获取状态文本
  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '下载中';
      case 'paused':
        return '已暂停';
      case 'stopped':
        return '已停止';
      case 'complete':
        return '已完成';
      case 'error':
        return '出错';
      default:
        return '未知状态';
    }
  }

  // 获取状态颜色
  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.blue;
      case 'paused':
        return Colors.orange;
      case 'stopped':
        return Colors.grey;
      case 'complete':
        return Colors.green;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 格式化剩余时间
  String _formatRemainingTime(DownloadTask task) {
    if (task.status != 'active' || task.downloadSpeed <= 0) {
      return '--:--:--';
    }
    
    int remainingBytes = task.totalLength - task.completedLength;
    if (remainingBytes <= 0) {
      return '00:00:00';
    }
    
    double remainingSeconds = remainingBytes / task.downloadSpeed;
    return calculateRemainingTime(remainingSeconds);
  }
}