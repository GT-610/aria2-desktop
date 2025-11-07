import 'package:flutter/material.dart';
import '../../../../models/aria2_instance.dart';
import '../../../../utils/logging.dart';

class InstanceCard extends StatefulWidget with Loggable {
  final Aria2Instance instance;
  final bool isActive;
  final bool isSelected;
  final bool isChecking;
  final bool isConnectionInProgress;
  final Function(Aria2Instance) onSelect;
  final Function(Aria2Instance) onCheckStatus;
  final Function(Aria2Instance) onToggleConnection;
  final Function(Aria2Instance) onEdit;
  final Function(Aria2Instance) onDelete;

  InstanceCard({
    super.key,
    required this.instance,
    required this.isActive,
    required this.isSelected,
    required this.isChecking,
    required this.isConnectionInProgress,
    required this.onSelect,
    required this.onCheckStatus,
    required this.onToggleConnection,
    required this.onEdit,
    required this.onDelete,
  }) {
    initLogger();
  }

  @override
  State<InstanceCard> createState() => _InstanceCardState();
}

class _InstanceCardState extends State<InstanceCard> {
  // 根据状态返回颜色
  Color _getStatusColor(ConnectionStatus status, ColorScheme colorScheme) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return colorScheme.surfaceContainerHighest;
      case ConnectionStatus.connecting:
        return colorScheme.primary;
      case ConnectionStatus.connected:
        return colorScheme.secondary;
      case ConnectionStatus.failed:
        return colorScheme.error;
    }
  }

  // 根据状态返回图标
  Widget _getStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return const Icon(Icons.link_off, size: 16, color: Colors.white);
      case ConnectionStatus.connecting:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );
      case ConnectionStatus.connected:
        return const Icon(Icons.link, size: 16, color: Colors.white);
      case ConnectionStatus.failed:
        return const Icon(Icons.error_outline, size: 16, color: Colors.white);
    }
  }

  // 根据状态返回状态标签
  Chip _getStatusChip(ConnectionStatus status, ColorScheme colorScheme) {
    String label;
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case ConnectionStatus.disconnected:
        label = '未连接';
        backgroundColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        break;
      case ConnectionStatus.connecting:
        label = '连接中';
        backgroundColor = colorScheme.primary.withOpacity(0.2);
        textColor = colorScheme.primary;
        break;
      case ConnectionStatus.connected:
        label = '已连接';
        backgroundColor = colorScheme.secondary.withOpacity(0.2);
        textColor = colorScheme.secondary;
        break;
      case ConnectionStatus.failed:
        label = '连接失败';
        backgroundColor = colorScheme.error.withOpacity(0.2);
        textColor = colorScheme.error;
        break;
    }

    return Chip(
      label: status == ConnectionStatus.connecting
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: textColor)),
              ],
            )
          : Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      backgroundColor: backgroundColor,
      padding: const EdgeInsets.all(0),
      visualDensity: VisualDensity.compact,
    );
  }

  // 根据状态返回操作按钮
  Widget _getStatusActionButton(ConnectionStatus status, bool isConnectionInProgress, BuildContext context, VoidCallback onPressed) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (status) {
      case ConnectionStatus.disconnected:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
          ),
          child: const Text('连接'),
        );
      
      case ConnectionStatus.connecting:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text('断开'),
            ],
          ),
        );
      
      case ConnectionStatus.connected:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.error),
          ),
          child: const Text('断开'),
        );
      
      case ConnectionStatus.failed:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
          ),
          child: const Text('重新连接'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      elevation: widget.isSelected ? 4 : 2,
      shadowColor: Colors.black.withOpacity(0.1),
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          widget.onSelect(widget.instance);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 实例名称和类型
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // 状态指示器 - 清晰区分四种状态
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor(widget.instance.status, colorScheme),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(widget.instance.status, colorScheme).withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: _getStatusIcon(widget.instance.status),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.instance.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          widget.instance.type == InstanceType.local ? '本地' : '远程',
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.all(0),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  // 状态标签 - 明确显示连接状态
                  Row(
                    children: [
                      _getStatusChip(widget.instance.status, colorScheme),
                      if (widget.isActive) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text('当前活跃'),
                          labelStyle: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 12,
                          ),
                          backgroundColor: colorScheme.primary,
                          padding: const EdgeInsets.all(0),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 实例详情
              Text(
                '${widget.instance.protocol}://${widget.instance.host}:${widget.instance.port}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.instance.type == InstanceType.local && widget.instance.aria2Path != null) ...[
                const SizedBox(height: 4),
                Text(
                  '路径: ${widget.instance.aria2Path}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // 版本信息
              if (widget.instance.version != null && widget.instance.version!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '版本: ${widget.instance.version}',
                  style: TextStyle(
                    color: colorScheme.tertiary,
                    fontSize: 12,
                  ),
                ),
              ],
              // 错误信息
              if (widget.instance.errorMessage != null && widget.instance.errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.warning,
                      size: 14,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.instance.errorMessage!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // 操作按钮
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 编辑按钮
                  TextButton(
                    onPressed: () => widget.onEdit(widget.instance),
                    child: const Text('编辑'),
                  ),
                  // 删除按钮
                  TextButton(
                    onPressed: () => widget.onDelete(widget.instance),
                    child: Text(
                      '删除',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                  // 状态操作按钮 - 根据不同状态显示不同按钮
                  _getStatusActionButton(widget.instance.status, widget.isConnectionInProgress, context, () => widget.onToggleConnection(widget.instance)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}