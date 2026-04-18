import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../generated/l10n/l10n.dart';
import '../../../../models/aria2_instance.dart';
import '../../../../models/settings.dart';
import '../../../../services/instance_manager.dart';
import '../../../../services/settings_service.dart';
import '../../builtin_instance_settings_page.dart';

class InstanceCard extends StatefulWidget {
  final Aria2Instance instance;
  final bool isSelected;
  final bool isChecking;
  final Function(Aria2Instance) onSelect;
  final Function(Aria2Instance) onCheckStatus;
  final Function(Aria2Instance) onToggleConnection;
  final Function(Aria2Instance) onEdit;
  final Function(Aria2Instance) onDelete;
  final Function(Aria2Instance) onOpenRemoteSettings;
  final Function(Aria2Instance) onOpenRemoteStatus;

  const InstanceCard({
    super.key,
    required this.instance,
    required this.isSelected,
    required this.isChecking,
    required this.onSelect,
    required this.onCheckStatus,
    required this.onToggleConnection,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenRemoteSettings,
    required this.onOpenRemoteStatus,
  });

  @override
  State<InstanceCard> createState() => _InstanceCardState();
}

class _InstanceCardState extends State<InstanceCard> {
  void _openBuiltinSettings(BuildContext context) {
    final settings = Provider.of<Settings>(context, listen: false);
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    final settingsService = Provider.of<SettingsService>(
      context,
      listen: false,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiProvider(
          providers: [
            ChangeNotifierProvider<Settings>.value(value: settings),
            ChangeNotifierProvider<InstanceManager>.value(
              value: instanceManager,
            ),
            ChangeNotifierProvider<SettingsService>.value(
              value: settingsService,
            ),
          ],
          child: const BuiltinInstanceSettingsPage(),
        ),
      ),
    );
  }

  void _openRemoteSettings(BuildContext context) {
    widget.onOpenRemoteSettings(widget.instance);
  }

  void _openRemoteStatus(BuildContext context) {
    widget.onOpenRemoteStatus(widget.instance);
  }

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

  Widget _getStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.disconnected:
        return const Icon(Icons.link_off, size: 16, color: Colors.white);
      case ConnectionStatus.connecting:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case ConnectionStatus.connected:
        return const Icon(Icons.link, size: 16, color: Colors.white);
      case ConnectionStatus.failed:
        return const Icon(Icons.error_outline, size: 16, color: Colors.white);
    }
  }

  Chip _getStatusChip(
    BuildContext context,
    ConnectionStatus status,
    ColorScheme colorScheme,
  ) {
    final l10n = AppLocalizations.of(context)!;
    late final String label;
    late final Color backgroundColor;
    late final Color textColor;

    switch (status) {
      case ConnectionStatus.disconnected:
        label = l10n.disconnected;
        backgroundColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        break;
      case ConnectionStatus.connecting:
        label = l10n.connecting;
        backgroundColor = colorScheme.primary.withValues(alpha: 0.2);
        textColor = colorScheme.primary;
        break;
      case ConnectionStatus.connected:
        label = l10n.connected;
        backgroundColor = colorScheme.secondary.withValues(alpha: 0.2);
        textColor = colorScheme.secondary;
        break;
      case ConnectionStatus.failed:
        label = l10n.failed;
        backgroundColor = colorScheme.error.withValues(alpha: 0.2);
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
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildInlineTextAction(
    BuildContext context, {
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool destructive = false,
    bool loading = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: destructive ? colorScheme.error : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildInlineIconAction({
    required BuildContext context,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    bool destructive = false,
    bool loading = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                icon,
                size: 20,
                color: destructive ? colorScheme.error : null,
              ),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        visualDensity: VisualDensity.compact,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildStatusAction(
    ConnectionStatus status,
    BuildContext context,
    VoidCallback onPressed,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (widget.instance.type == InstanceType.builtin) {
      switch (status) {
        case ConnectionStatus.disconnected:
          return _buildInlineTextAction(
            context,
            onPressed: onPressed,
            icon: Icons.link,
            label: l10n.connect,
          );
        case ConnectionStatus.failed:
          return _buildInlineTextAction(
            context,
            onPressed: onPressed,
            icon: Icons.refresh,
            label: l10n.retry,
            destructive: true,
          );
        case ConnectionStatus.connecting:
          return _buildInlineTextAction(
            context,
            onPressed: null,
            icon: Icons.link,
            label: l10n.connecting,
            loading: true,
          );
        default:
          return const SizedBox.shrink();
      }
    }

    switch (status) {
      case ConnectionStatus.disconnected:
        return _buildInlineIconAction(
          context: context,
          tooltip: l10n.connect,
          icon: Icons.link,
          onPressed: onPressed,
        );
      case ConnectionStatus.connecting:
        return _buildInlineIconAction(
          context: context,
          tooltip: l10n.disconnect,
          icon: Icons.link_off,
          onPressed: onPressed,
          loading: true,
        );
      case ConnectionStatus.connected:
        return _buildInlineIconAction(
          context: context,
          tooltip: l10n.disconnect,
          icon: Icons.link_off,
          onPressed: onPressed,
          destructive: true,
        );
      case ConnectionStatus.failed:
        return _buildInlineIconAction(
          context: context,
          tooltip: l10n.retry,
          icon: Icons.refresh,
          onPressed: onPressed,
          destructive: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final builtinVersionText =
        widget.instance.version != null && widget.instance.version!.isNotEmpty
        ? l10n.aria2Version(widget.instance.version!)
        : l10n.versionWillAppearAfterConnection;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onSelect(widget.instance),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor(
                            widget.instance.status,
                            colorScheme,
                          ),
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
                          widget.instance.type == InstanceType.builtin
                              ? l10n.builtin
                              : l10n.remote,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor:
                            widget.instance.type == InstanceType.builtin
                            ? colorScheme.primary.withValues(alpha: 0.2)
                            : colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(
                          color: widget.instance.type == InstanceType.builtin
                              ? colorScheme.primary
                              : null,
                        ),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  _getStatusChip(context, widget.instance.status, colorScheme),
                ],
              ),
              const SizedBox(height: 8),
              if (widget.instance.type != InstanceType.builtin)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.instance.rpcUrl,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildInlineIconAction(
                      context: context,
                      tooltip: l10n.check,
                      icon: Icons.wifi_find_outlined,
                      onPressed: widget.isChecking
                          ? null
                          : () => widget.onCheckStatus(widget.instance),
                      loading: widget.isChecking,
                    ),
                    _buildInlineIconAction(
                      context: context,
                      tooltip: l10n.remoteStatusMaintenance,
                      icon: Icons.monitor_heart_outlined,
                      onPressed:
                          widget.instance.status == ConnectionStatus.connected
                          ? () => _openRemoteStatus(context)
                          : null,
                    ),
                    _buildInlineIconAction(
                      context: context,
                      tooltip: l10n.remoteAria2Settings,
                      icon: Icons.settings_outlined,
                      onPressed:
                          widget.instance.status == ConnectionStatus.connected
                          ? () => _openRemoteSettings(context)
                          : null,
                    ),
                    _buildInlineIconAction(
                      context: context,
                      tooltip: l10n.editConnectionProfile,
                      icon: Icons.edit_outlined,
                      onPressed: () => widget.onEdit(widget.instance),
                    ),
                    _buildInlineIconAction(
                      context: context,
                      tooltip: l10n.delete,
                      icon: Icons.delete_outline,
                      onPressed: () => widget.onDelete(widget.instance),
                      destructive: true,
                    ),
                    _buildStatusAction(
                      widget.instance.status,
                      context,
                      () => widget.onToggleConnection(widget.instance),
                    ),
                  ],
                ),
              if (widget.instance.type != InstanceType.builtin &&
                  widget.instance.rpcRequestHeaders.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.rpcHeadersConfigured,
                  style: TextStyle(color: colorScheme.tertiary, fontSize: 12),
                ),
              ],
              if (widget.instance.type == InstanceType.builtin)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        builtinVersionText,
                        style: TextStyle(
                          color: colorScheme.tertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.settings,
                      child: IconButton(
                        onPressed: () => _openBuiltinSettings(context),
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        visualDensity: VisualDensity.compact,
                        splashRadius: 20,
                      ),
                    ),
                    if (widget.instance.status ==
                            ConnectionStatus.disconnected ||
                        widget.instance.status == ConnectionStatus.connecting ||
                        widget.instance.status == ConnectionStatus.failed) ...[
                      const SizedBox(width: 4),
                      _buildStatusAction(
                        widget.instance.status,
                        context,
                        () => widget.onToggleConnection(widget.instance),
                      ),
                    ],
                  ],
                ),
              if (widget.instance.errorMessage != null &&
                  widget.instance.errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.warning, size: 14, color: colorScheme.error),
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
            ],
          ),
        ),
      ),
    );
  }
}
