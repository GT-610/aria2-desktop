import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';

import '../../../../generated/l10n/l10n.dart';
import '../../../../models/aria2_instance.dart';
import '../../builtin_instance_settings_page.dart';

class InstanceCard extends StatefulWidget {
  final Aria2Instance instance;
  final bool isSelected;
  final bool isChecking;
  final bool isConnectionInProgress;
  final Function(Aria2Instance) onSelect;
  final Function(Aria2Instance) onCheckStatus;
  final Function(Aria2Instance) onToggleConnection;
  final Function(Aria2Instance) onEdit;
  final Function(Aria2Instance) onDelete;

  const InstanceCard({
    super.key,
    required this.instance,
    required this.isSelected,
    required this.isChecking,
    required this.isConnectionInProgress,
    required this.onSelect,
    required this.onCheckStatus,
    required this.onToggleConnection,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<InstanceCard> createState() => _InstanceCardState();
}

class _InstanceCardState extends State<InstanceCard> {
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
          child: fl.SizedLoading.small,
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
                  child: fl.SizedLoading.small,
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

  Widget _getStatusActionButton(
    ConnectionStatus status,
    BuildContext context,
    VoidCallback onPressed,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (widget.instance.type == InstanceType.builtin) {
      switch (status) {
        case ConnectionStatus.disconnected:
          return FilledButton(onPressed: onPressed, child: Text(l10n.connect));
        case ConnectionStatus.failed:
          return FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            child: Text(l10n.retry),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    switch (status) {
      case ConnectionStatus.disconnected:
        return FilledButton(onPressed: onPressed, child: Text(l10n.connect));
      case ConnectionStatus.connecting:
        return FilledButton(
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: fl.SizedLoading.small,
              ),
              const SizedBox(width: 8),
              Text(l10n.disconnect),
            ],
          ),
        );
      case ConnectionStatus.connected:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: colorScheme.error),
          ),
          child: Text(l10n.disconnect),
        );
      case ConnectionStatus.failed:
        return FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
          child: Text(l10n.retry),
        );
    }
  }

  Widget _buildCheckStatusButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton.icon(
      onPressed: widget.isChecking
          ? null
          : () => widget.onCheckStatus(widget.instance),
      icon: widget.isChecking
          ? const SizedBox(width: 16, height: 16, child: fl.SizedLoading.small)
          : const Icon(Icons.wifi_find_outlined, size: 18),
      label: Text(l10n.check),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: widget.isSelected ? 4 : 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
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
                              ? AppLocalizations.of(context)!.builtin
                              : AppLocalizations.of(context)!.remote,
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
                Text(
                  '${widget.instance.protocol}://${widget.instance.host}:${widget.instance.port}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              if (widget.instance.type == InstanceType.builtin)
                Text(
                  widget.instance.version != null &&
                          widget.instance.version!.isNotEmpty
                      ? AppLocalizations.of(
                          context,
                        )!.aria2Version(widget.instance.version!)
                      : AppLocalizations.of(
                          context,
                        )!.versionWillAppearAfterConnection,
                  style: TextStyle(color: colorScheme.tertiary, fontSize: 12),
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
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCheckStatusButton(context),
                  if (widget.instance.type == InstanceType.builtin)
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BuiltinInstanceSettingsPage(),
                          ),
                        );
                      },
                      child: Text(AppLocalizations.of(context)!.settings),
                    ),
                  if (widget.instance.type != InstanceType.builtin) ...[
                    TextButton(
                      onPressed: () => widget.onEdit(widget.instance),
                      child: Text(AppLocalizations.of(context)!.edit),
                    ),
                    TextButton(
                      onPressed: () => widget.onDelete(widget.instance),
                      child: Text(
                        AppLocalizations.of(context)!.delete,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  ],
                  _getStatusActionButton(
                    widget.instance.status,
                    context,
                    () => widget.onToggleConnection(widget.instance),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
