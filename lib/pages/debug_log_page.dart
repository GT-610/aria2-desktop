import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../generated/l10n/l10n.dart';
import '../services/debug_log_store.dart';
import '../utils/logging.dart';

final _logger = taggedLogger('DebugLogPage');

class DebugLogPage extends StatelessWidget {
  const DebugLogPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).copyButtonLabel,
            onPressed: () async {
              try {
                await DebugLogStore.copy();
              } catch (error, stackTrace) {
                _logger.e(
                  'Failed to copy debug logs',
                  error: error,
                  stackTrace: stackTrace,
                );
                if (context.mounted) {
                  final l10n = AppLocalizations.of(context)!;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.operationFailed('$error'))),
                  );
                }
              }
            },
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
            onPressed: () => _confirmClear(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ColoredBox(
        color: Colors.black,
        child: ValueListenableBuilder<List<DebugLogEntry>>(
          valueListenable: DebugLogStore.entries,
          builder: (context, entries, _) {
            if (entries.isEmpty) {
              return const SizedBox.expand();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _LogEntry(entry: entries[index]),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final materialL10n = MaterialLocalizations.of(dialogContext);
        final l10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(l10n.clearLogsConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(materialL10n.cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(materialL10n.okButtonLabel),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      DebugLogStore.clear();
    }
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry({required this.entry});

  final DebugLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      Level.SEVERE => const Color(0xffef6c9f),
      Level.WARNING => Colors.yellow,
      _ => Colors.cyan,
    };
    return SelectableText.rich(
      TextSpan(
        style: const TextStyle(color: Colors.white),
        children: [
          TextSpan(
            text: '${entry.plainText}\n',
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}
