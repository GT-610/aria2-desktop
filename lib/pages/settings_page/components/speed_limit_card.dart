import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/settings.dart';
import '../../../utils/speed_schedule.dart';
import '../../../widgets/app_card.dart';
import '../../components/quick_speed_limit_dialog.dart';

/// Settings card for global speed limits: master switch, overall up/down
/// limits, and an optional weekday/time schedule window.
class SpeedLimitCard extends StatefulWidget {
  const SpeedLimitCard({super.key, required this.settings});

  final Settings settings;

  @override
  State<SpeedLimitCard> createState() => _SpeedLimitCardState();
}

class _SpeedLimitCardState extends State<SpeedLimitCard> {
  late final TextEditingController _downloadController;
  late final TextEditingController _uploadController;

  @override
  void initState() {
    super.initState();
    _downloadController = TextEditingController(
      text: _limitText(widget.settings.maxOverallDownloadLimit),
    );
    _uploadController = TextEditingController(
      text: _limitText(widget.settings.maxOverallUploadLimit),
    );
  }

  @override
  void dispose() {
    _downloadController.dispose();
    _uploadController.dispose();
    super.dispose();
  }

  String _limitText(int value) => value <= 0 ? '' : '$value';

  Future<void> _pushToBuiltin() async {
    try {
      await applySpeedLimitsToBuiltin(context);
    } catch (_) {
      // Non-fatal: limits apply on the next engine start regardless.
    }
  }

  Future<void> _commitLimits() async {
    final download = int.tryParse(_downloadController.text.trim()) ?? 0;
    final upload = int.tryParse(_uploadController.text.trim()) ?? 0;
    await widget.settings.setMaxOverallDownloadLimit(download);
    await widget.settings.setMaxOverallUploadLimit(upload);
    await _pushToBuiltin();
  }

  List<int> get _timeChoices {
    final choices = <int>[];
    for (var minutes = 0; minutes <= minutesPerDay; minutes += 30) {
      choices.add(minutes);
    }
    return choices;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = widget.settings;
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.speedLimitEnabledTitle),
            value: settings.speedLimitEnabled,
            onChanged: (value) async {
              await settings.setSpeedLimitEnabled(value);
              await _pushToBuiltin();
            },
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _downloadController,
                  enabled: settings.speedLimitEnabled,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.maxOverallDownloadLimit,
                    suffixText: 'KB/s',
                    helperText: l10n.downloadLimitTip,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _commitLimits(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _uploadController,
                  enabled: settings.speedLimitEnabled,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.maxOverallUploadLimit,
                    suffixText: 'KB/s',
                    helperText: l10n.downloadLimitTip,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _commitLimits(),
                ),
              ),
              IconButton(
                tooltip: l10n.save,
                onPressed: _commitLimits,
                icon: const Icon(Icons.save_outlined),
              ),
            ],
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.speedScheduleTitle),
            subtitle: settings.speedScheduleEnabled
                ? Text(
                    '${formatMinutesAsHm(settings.speedScheduleStartMinutes)}'
                    ' - '
                    '${formatMinutesAsHm(settings.speedScheduleEndMinutes)}',
                  )
                : null,
            value: settings.speedScheduleEnabled,
            onChanged: settings.speedLimitEnabled
                ? (value) async {
                    await settings.setSpeedSchedule(enabled: value);
                    await _pushToBuiltin();
                  }
                : null,
          ),
          if (settings.speedScheduleEnabled) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 0; day < 7; day++)
                  FilterChip(
                    label: Text(_dayLabel(context, day)),
                    selected: ((settings.speedScheduleDays >> day) & 1) == 1,
                    onSelected: (selected) {
                      var days = settings.speedScheduleDays;
                      days = selected ? days | (1 << day) : days & ~(1 << day);
                      settings.setSpeedSchedule(days: days);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.speedScheduleFrom),
                const SizedBox(width: 8),
                Expanded(child: _scheduleDropdown(true)),
                const SizedBox(width: 16),
                Text(l10n.speedScheduleTo),
                const SizedBox(width: 8),
                Expanded(child: _scheduleDropdown(false)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.downloadLimitTip,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _dayLabel(BuildContext context, int day) {
    // DateFormat weekdays are Monday-first which matches the bitmask.
    final reference = DateTime(2024, 1, day + 1); // 2024-01-01 was a Monday.
    return DateFormat.E(
      AppLocalizations.of(context)!.localeName,
    ).format(reference);
  }

  Widget _scheduleDropdown(bool isStart) {
    final settings = widget.settings;
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
        settings.setSpeedSchedule(
          startMinutes: isStart ? value : null,
          endMinutes: isStart ? null : value,
        );
      },
    );
  }
}
