import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/settings.dart';
import '../../../utils/logging.dart';
import '../../../utils/speed_schedule.dart';
import '../../../widgets/app_card.dart';
import '../../components/quick_speed_limit_dialog.dart';

final _logger = taggedLogger('SpeedLimitCard');

Future<void> _pushSpeedLimits(BuildContext context) async {
  try {
    final applied = await applySpeedLimitsToBuiltin(context);
    if (!applied) {
      _logger.w(
        'Speed limits were not pushed because the built-in instance is '
        'unavailable or rejected the update',
      );
    }
  } catch (error, stackTrace) {
    _logger.w(
      'Failed to push speed limits to the built-in instance',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Speed-limit settings built from the same tiles used across the settings
/// page: a master switch row, value rows that open edit dialogs, and a
/// schedule card with inline day/time controls (run-mode card pattern).
class SpeedLimitCard extends StatelessWidget {
  const SpeedLimitCard({super.key, required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        AppCard(
          child: ListTile(
            title: Text(l10n.speedLimitEnabledTitle),
            subtitle: Text(l10n.speedLimitEnabledTip),
            trailing: Switch.adaptive(
              value: settings.speedLimitEnabled,
              onChanged: (value) =>
                  _update(context, () => settings.setSpeedLimitEnabled(value)),
            ),
          ),
        ),
        _limitTile(
          context,
          title: l10n.maxOverallUploadSpeed,
          value: settings.maxOverallUploadLimit,
          onEdit: () => _showLimitDialog(context, isUpload: true),
        ),
        _limitTile(
          context,
          title: l10n.maxOverallDownloadSpeed,
          value: settings.maxOverallDownloadLimit,
          onEdit: () => _showLimitDialog(context, isUpload: false),
        ),
        _scheduleCard(context),
      ],
    );
  }

  Widget _limitTile(
    BuildContext context, {
    required String title,
    required int value,
    required VoidCallback onEdit,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final enabledColor = settings.speedLimitEnabled
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return AppCard(
      child: ListTile(
        enabled: settings.speedLimitEnabled,
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value <= 0 ? l10n.unlimited : '$value KB/s',
              style: TextStyle(color: enabledColor),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  Widget _scheduleCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Column(
        children: [
          ListTile(
            enabled: settings.speedLimitEnabled,
            title: Text(l10n.speedScheduleTitle),
            subtitle: settings.speedScheduleEnabled
                ? Text(
                    '${formatMinutesAsHm(settings.speedScheduleStartMinutes)}'
                    ' - '
                    '${formatMinutesAsHm(settings.speedScheduleEndMinutes)}',
                  )
                : null,
            trailing: Switch.adaptive(
              value: settings.speedScheduleEnabled,
              onChanged: settings.speedLimitEnabled
                  ? (value) => _update(
                      context,
                      () => settings.setSpeedSchedule(enabled: value),
                    )
                  : null,
            ),
          ),
          if (settings.speedLimitEnabled && settings.speedScheduleEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var day = 0; day < 7; day++)
                        FilterChip(
                          label: Text(_dayLabel(context, day)),
                          selected:
                              ((settings.speedScheduleDays >> day) & 1) == 1,
                          onSelected: (selected) {
                            var days = settings.speedScheduleDays;
                            days = selected
                                ? days | (1 << day)
                                : days & ~(1 << day);
                            _update(
                              context,
                              () => settings.setSpeedSchedule(days: days),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(l10n.speedScheduleFrom),
                      const SizedBox(width: 8),
                      Expanded(child: _scheduleDropdown(context, true)),
                      const SizedBox(width: 16),
                      Text(l10n.speedScheduleTo),
                      const SizedBox(width: 8),
                      Expanded(child: _scheduleDropdown(context, false)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _scheduleDropdown(BuildContext context, bool isStart) {
    final current = isStart
        ? settings.speedScheduleStartMinutes
        : settings.speedScheduleEndMinutes;
    return DropdownButton<int>(
      value: current,
      isExpanded: true,
      items: [
        for (final choice in _timeChoices)
          DropdownMenuItem<int>(
            value: choice,
            child: Text(formatMinutesAsHm(choice)),
          ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        _update(
          context,
          () => settings.setSpeedSchedule(
            startMinutes: isStart ? value : null,
            endMinutes: isStart ? null : value,
          ),
        );
      },
    );
  }

  List<int> get _timeChoices {
    final choices = <int>[];
    for (var minutes = 0; minutes <= minutesPerDay; minutes += 30) {
      choices.add(minutes);
    }
    return choices;
  }

  String _dayLabel(BuildContext context, int day) {
    // DateFormat weekdays are Monday-first which matches the bitmask.
    final reference = DateTime(2024, 1, day + 1); // 2024-01-01 was a Monday.
    return DateFormat.E(
      AppLocalizations.of(context)!.localeName,
    ).format(reference);
  }

  Future<void> _showLimitDialog(
    BuildContext context, {
    required bool isUpload,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _LimitEditDialog(settings: settings, isUpload: isUpload),
    );
  }

  Future<void> _update(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to persist speed-limit settings',
        error: error,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.saveSettingsFailed)));
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _pushSpeedLimits(context);
  }
}

class _LimitEditDialog extends StatefulWidget {
  const _LimitEditDialog({required this.settings, required this.isUpload});

  final Settings settings;
  final bool isUpload;

  @override
  State<_LimitEditDialog> createState() => _LimitEditDialogState();
}

class _LimitEditDialogState extends State<_LimitEditDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final value = widget.isUpload
        ? widget.settings.maxOverallUploadLimit
        : widget.settings.maxOverallDownloadLimit;
    _controller = TextEditingController(text: value <= 0 ? '' : '$value');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);

    final value = int.tryParse(_controller.text.trim()) ?? 0;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (widget.isUpload) {
        await widget.settings.setMaxOverallUploadLimit(value);
      } else {
        await widget.settings.setMaxOverallDownloadLimit(value);
      }
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to persist speed-limit settings',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.saveSettingsFailed)),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    await _pushSpeedLimits(context);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.isUpload
            ? l10n.maxOverallUploadSpeed
            : l10n.maxOverallDownloadSpeed,
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          suffixText: 'KB/s',
          border: const OutlineInputBorder(),
          helperText: widget.isUpload
              ? l10n.uploadLimitTip
              : l10n.downloadLimitTip,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.save)),
      ],
    );
  }
}
