import 'package:flutter/material.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/settings.dart';
import '../../../utils/file_category.dart';

/// Editor for the extension -> subdirectory routing rules (max
/// [maxFileCategoryRules] entries).
Future<void> showFileCategoryEditorDialog(
  BuildContext context,
  Settings settings,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _FileCategoryEditorDialog(settings: settings),
  );
}

class _RuleRow {
  _RuleRow({required String extensions, required String subdirectory})
    : extensionsController = TextEditingController(text: extensions),
      subdirectoryController = TextEditingController(text: subdirectory);

  final TextEditingController extensionsController;
  final TextEditingController subdirectoryController;

  void dispose() {
    extensionsController.dispose();
    subdirectoryController.dispose();
  }
}

class _FileCategoryEditorDialog extends StatefulWidget {
  const _FileCategoryEditorDialog({required this.settings});

  final Settings settings;

  @override
  State<_FileCategoryEditorDialog> createState() =>
      _FileCategoryEditorDialogState();
}

class _FileCategoryEditorDialogState extends State<_FileCategoryEditorDialog> {
  late final List<_RuleRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.settings.fileCategoryRules
        .map(
          (rule) => _RuleRow(
            extensions: rule.extensions.join(', '),
            subdirectory: rule.subdirectory,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  bool get _canAddMore => _rows.length < maxFileCategoryRules;

  Future<void> _save() async {
    final rules = <FileCategoryRule>[];
    for (final row in _rows) {
      final rule = FileCategoryRule.tryParse(
        FileCategoryRule(
          extensions: {
            for (final extension in row.extensionsController.text.split(','))
              if (extension.trim().isNotEmpty) extension.trim(),
          },
          subdirectory: row.subdirectoryController.text,
        ).encode(),
      );
      if (rule != null) {
        rules.add(rule);
      }
    }
    await widget.settings.setFileCategoryRules(rules);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.fileCategoriesTitle),
      content: SizedBox(
        width: 520,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(l10n.fileCategoriesEmptyHint),
              )
            else ...[
              Expanded(
                child: ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    return Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: row.extensionsController,
                            decoration: InputDecoration(
                              labelText: l10n.fileCategoryExtensionsLabel,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: row.subdirectoryController,
                            decoration: InputDecoration(
                              labelText: l10n.fileCategorySubdirLabel,
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.delete,
                          onPressed: () {
                            setState(() {
                              final removed = _rows.removeAt(index);
                              removed.dispose();
                            });
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (!_canAddMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.fileCategoriesMaxHint),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _canAddMore
              ? () {
                  setState(
                    () => _rows.add(_RuleRow(extensions: '', subdirectory: '')),
                  );
                }
              : null,
          icon: const Icon(Icons.add),
          label: Text(l10n.fileCategoryAddRule),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
