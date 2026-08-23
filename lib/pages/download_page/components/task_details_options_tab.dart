import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../services/download_data_service.dart';
import '../../../services/instance_manager.dart';
import '../../../utils/logging.dart';
import '../enums.dart';
import '../models/download_task.dart';

final _logger = taggedLogger('TaskDetailsOptionsTab');

enum _OptionKind { text, integer, decimal, boolValue }

class _OptionFieldSpec {
  const _OptionFieldSpec({
    required this.key,
    required this.label,
    required this.kind,
    this.editableWhileActive = false,
  });

  final String key;
  final String Function(AppLocalizations l10n) label;
  final _OptionKind kind;

  /// aria2.changeOption only accepts a small subset of keys while a task is
  /// active; the rest require waiting/paused status.
  final bool editableWhileActive;
}

final _optionSpecs = <_OptionFieldSpec>[
  _OptionFieldSpec(
    key: 'max-download-limit',
    label: (l10n) => l10n.optionPerTaskDownloadLimit,
    kind: _OptionKind.text,
    editableWhileActive: true,
  ),
  _OptionFieldSpec(
    key: 'max-upload-limit',
    label: (l10n) => l10n.optionPerTaskUploadLimit,
    kind: _OptionKind.text,
    editableWhileActive: true,
  ),
  _OptionFieldSpec(
    key: 'bt-max-peers',
    label: (l10n) => l10n.btMaxPeers,
    kind: _OptionKind.integer,
    editableWhileActive: true,
  ),
  _OptionFieldSpec(
    key: 'force-save',
    label: (l10n) => l10n.forceSaveOption,
    kind: _OptionKind.boolValue,
    editableWhileActive: true,
  ),
  _OptionFieldSpec(
    key: 'user-agent',
    label: (l10n) => l10n.userAgent,
    kind: _OptionKind.text,
  ),
  _OptionFieldSpec(
    key: 'referer',
    label: (l10n) => l10n.referer,
    kind: _OptionKind.text,
  ),
  _OptionFieldSpec(
    key: 'all-proxy',
    label: (l10n) => l10n.perTaskProxy,
    kind: _OptionKind.text,
  ),
  _OptionFieldSpec(
    key: 'bt-tracker',
    label: (l10n) => l10n.trackers,
    kind: _OptionKind.text,
  ),
  _OptionFieldSpec(
    key: 'seed-ratio',
    label: (l10n) => l10n.seedRatio,
    kind: _OptionKind.decimal,
  ),
  _OptionFieldSpec(
    key: 'seed-time',
    label: (l10n) => l10n.seedTimeMinutes,
    kind: _OptionKind.decimal,
  ),
];

/// Per-task options editor backed by aria2.getOption / aria2.changeOption.
///
/// Edits are staged in a pending overlay and only committed on save;
/// discarding restores the values originally reported by getOption. Fields
/// are gated by task status following aria2's changeOption rules: active
/// tasks expose only a small subset of tunables.
class TaskDetailsOptionsTab extends StatefulWidget {
  const TaskDetailsOptionsTab({super.key, required this.task, this.onSaved});

  final DownloadTask task;
  final VoidCallback? onSaved;

  @override
  State<TaskDetailsOptionsTab> createState() => _TaskDetailsOptionsTabState();
}

class _TaskDetailsOptionsTabState extends State<TaskDetailsOptionsTab> {
  /// Values as last reported by aria2.getOption.
  Map<String, String>? _original;

  /// Staged edits not yet committed to aria2.
  Map<String, String> _pending = {};

  final Set<String> _dirtyKeys = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<_OptionFieldSpec> get _applicableSpecs {
    final isActive = widget.task.status == DownloadStatus.active;
    return _optionSpecs
        .where((spec) => !isActive || spec.editableWhileActive)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadOptions());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final instanceManager = context.read<InstanceManager>();
      final downloadDataService = context.read<DownloadDataService>();
      final instance = instanceManager.getInstanceById(widget.task.instanceId);
      if (instance == null) {
        throw Exception('instance not connected');
      }
      final options = await downloadDataService
          .clientFor(instance)
          .getOption(widget.task.id);
      if (!mounted) return;
      _disposeControllers();
      _original = {
        for (final entry in options.entries) entry.key: '${entry.value ?? ''}',
      };
      _pending = {};
      _dirtyKeys.clear();
      setState(() => _loading = false);
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to load options for task ${widget.task.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }

  /// Effective value shown for [key]: the staged edit when present, otherwise
  /// the original option value.
  String _effectiveValue(String key) {
    return _pending[key] ?? _original?[key] ?? '';
  }

  TextEditingController _controllerFor(_OptionFieldSpec spec) {
    return _controllers.putIfAbsent(
      spec.key,
      () => TextEditingController(text: _effectiveValue(spec.key)),
    );
  }

  void _stageTextValue(_OptionFieldSpec spec, String value) {
    final original = _original?[spec.key] ?? '';
    if (_effectiveValue(spec.key) == value) {
      return;
    }
    setState(() {
      if (value == original) {
        _pending = {..._pending}..remove(spec.key);
        _dirtyKeys.remove(spec.key);
      } else {
        _pending = {..._pending, spec.key: value};
        _dirtyKeys.add(spec.key);
      }
    });
  }

  void _discardChanges() {
    setState(() {
      _pending = {};
      _dirtyKeys.clear();
      for (final entry in _controllers.entries) {
        entry.value.text = _effectiveValue(entry.key);
      }
    });
  }

  Future<void> _saveChanges() async {
    if (_dirtyKeys.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);

    final updates = <String, String>{};
    for (final key in _dirtyKeys) {
      final spec = _optionSpecs.firstWhere((candidate) => candidate.key == key);
      switch (spec.kind) {
        case _OptionKind.boolValue:
          updates[key] = _effectiveValue(key) == 'true' ? 'true' : 'false';
        case _OptionKind.integer || _OptionKind.decimal || _OptionKind.text:
          final value =
              _controllers[key]?.text.trim() ?? _effectiveValue(key).trim();
          if (!_isValidNumericValue(spec, value)) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.operationFailed(spec.label(l10n)))),
            );
            setState(() => _saving = false);
            return;
          }
          // Empty text clears the per-task override where supported.
          updates[key] = value;
      }
    }

    try {
      final instanceManager = context.read<InstanceManager>();
      final downloadDataService = context.read<DownloadDataService>();
      final instance = instanceManager.getInstanceById(widget.task.instanceId);
      if (instance == null) {
        throw Exception('instance not connected');
      }
      await downloadDataService
          .clientFor(instance)
          .changeOption(widget.task.id, updates);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.optionsSaved)),
      );
      setState(() {
        final nextOriginal = Map<String, String>.from(_original ?? {});
        for (final entry in updates.entries) {
          nextOriginal[entry.key] = entry.value;
        }
        _original = nextOriginal;
        _pending = {};
        _dirtyKeys.clear();
        for (final entry in _controllers.entries) {
          entry.value.text = _effectiveValue(entry.key);
        }
        _saving = false;
      });
      widget.onSaved?.call();
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to save options for task ${widget.task.id}',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.optionsLoadFailed(_error!)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => unawaited(_loadOptions()),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final specs = _applicableSpecs;
    final isActive = widget.task.status == DownloadStatus.active;

    return Column(
      children: [
        if (isActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l10n.optionsActiveOnlyHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: specs.length,
            itemBuilder: (context, index) => _buildField(context, specs[index]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _dirtyKeys.isEmpty || _saving
                    ? null
                    : _discardChanges,
                child: Text(l10n.discard),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _dirtyKeys.isEmpty || _saving ? null : _saveChanges,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(l10n.save),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField(BuildContext context, _OptionFieldSpec spec) {
    switch (spec.kind) {
      case _OptionKind.boolValue:
        final current = _effectiveValue(spec.key) == 'true';
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(spec.label(AppLocalizations.of(context)!)),
          value: current,
          onChanged: _saving
              ? null
              : (value) {
                  _stageTextValue(spec, value ? 'true' : 'false');
                },
        );
      case _OptionKind.integer || _OptionKind.decimal || _OptionKind.text:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _controllerFor(spec),
            enabled: !_saving,
            keyboardType: switch (spec.kind) {
              _OptionKind.integer => TextInputType.number,
              _OptionKind.decimal => const TextInputType.numberWithOptions(
                decimal: true,
              ),
              _ => null,
            },
            inputFormatters: switch (spec.kind) {
              _OptionKind.integer => <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              _OptionKind.decimal => <TextInputFormatter>[
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return RegExp(r'^\d*(?:\.\d*)?$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue;
                }),
              ],
              _ => null,
            },
            decoration: InputDecoration(
              labelText: spec.label(AppLocalizations.of(context)!),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: _dirtyKeys.contains(spec.key)
                  ? Icon(
                      Icons.circle,
                      size: 8,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
            ),
            maxLines: spec.key == 'bt-tracker' ? 3 : 1,
            onChanged: (text) => _stageTextValue(spec, text.trim()),
          ),
        );
    }
  }

  bool _isValidNumericValue(_OptionFieldSpec spec, String value) {
    if (value.isEmpty || spec.kind == _OptionKind.text) {
      return true;
    }
    return switch (spec.kind) {
      _OptionKind.integer => (int.tryParse(value) ?? -1) >= 0,
      _OptionKind.decimal => (double.tryParse(value) ?? -1) >= 0,
      _ => true,
    };
  }
}
