import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/settings.dart';
import '../services/instance_manager.dart';
import '../services/settings_service.dart';

class BuiltinInstanceSettingsPage extends StatefulWidget {
  const BuiltinInstanceSettingsPage({super.key});

  @override
  State<BuiltinInstanceSettingsPage> createState() =>
      _BuiltinInstanceSettingsPageState();
}

class _BuiltinInstanceSettingsPageState
    extends State<BuiltinInstanceSettingsPage> {
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<Settings>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Built-in Instance Settings'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showBackConfirmationDialog(context, settings),
        ),
        actions: [
          TextButton(
            onPressed: _hasChanges ? () => _saveSettings(settings) : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _hasChanges
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: _hasChanges
                ? () => _saveAndApplySettings(settings)
                : null,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: fl.SizedLoading.small,
                  )
                : Text(
                    'Save & Apply',
                    style: TextStyle(
                      color: _hasChanges
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Connection', theme),
            _buildCard(
              theme: theme,
              children: [
                _buildTextFieldSetting(
                  'RPC listen port',
                  settings.rpcListenPort.toString(),
                  (value) {
                    settings.setRpcListenPort(int.tryParse(value) ?? 16800);
                    _markChanged();
                  },
                  keyboardType: TextInputType.number,
                  helperText: 'Default: 16800',
                ),
                _buildTextFieldSetting(
                  'RPC secret',
                  settings.rpcSecret,
                  (value) {
                    settings.setRpcSecret(value);
                    _markChanged();
                  },
                  obscureText: true,
                  helperText: 'Leave empty to disable secret auth',
                ),
              ],
            ),
            _buildSectionHeader('Transfer', theme),
            _buildCard(
              theme: theme,
              children: [
                _buildNumberSetting(
                  'Max concurrent downloads',
                  settings.maxConcurrentDownloads,
                  (value) {
                    settings.setMaxConcurrentDownloads(value);
                    _markChanged();
                  },
                  min: 1,
                  max: 16,
                ),
                _buildNumberSetting(
                  'Max connections per server',
                  settings.maxConnectionPerServer,
                  (value) {
                    settings.setMaxConnectionPerServer(value);
                    _markChanged();
                  },
                  min: 1,
                  max: 128,
                ),
                _buildNumberSetting(
                  'Split count',
                  settings.split,
                  (value) {
                    settings.setSplit(value);
                    _markChanged();
                  },
                  min: 1,
                  max: 128,
                ),
                _buildSwitchSetting(
                  'Continue unfinished downloads',
                  settings.continueDownloads,
                  (value) {
                    settings.setContinueDownloads(value);
                    _markChanged();
                  },
                ),
              ],
            ),
            _buildSectionHeader('Speed Limits', theme),
            _buildCard(
              theme: theme,
              children: [
                _buildNumberSetting(
                  'Max overall download limit (KB/s)',
                  settings.maxOverallDownloadLimit,
                  (value) {
                    settings.setMaxOverallDownloadLimit(value);
                    _markChanged();
                  },
                  min: 0,
                  max: 65535,
                  suffix: '0 means unlimited',
                ),
                _buildNumberSetting(
                  'Max overall upload limit (KB/s)',
                  settings.maxOverallUploadLimit,
                  (value) {
                    settings.setMaxOverallUploadLimit(value);
                    _markChanged();
                  },
                  min: 0,
                  max: 65535,
                  suffix: '0 means unlimited',
                ),
              ],
            ),
            _buildSectionHeader('BT / PT', theme),
            _buildCard(
              theme: theme,
              children: [
                _buildSwitchSetting(
                  'Save BT metadata',
                  settings.btSaveMetadata,
                  (value) {
                    settings.setBtSaveMetadata(value);
                    _markChanged();
                  },
                ),
                _buildSwitchSetting(
                  'Load saved BT metadata',
                  settings.btLoadSavedMetadata,
                  (value) {
                    settings.setBtLoadSavedMetadata(value);
                    _markChanged();
                  },
                ),
                _buildSwitchSetting(
                  'Force BT encryption',
                  settings.btForceEncryption,
                  (value) {
                    settings.setBtForceEncryption(value);
                    _markChanged();
                  },
                ),
                _buildSwitchSetting(
                  'Keep seeding after completion',
                  settings.keepSeeding,
                  (value) {
                    settings.setKeepSeeding(value);
                    _markChanged();
                  },
                ),
                if (!settings.keepSeeding) ...[
                  _buildNumberSetting(
                    'Seed ratio',
                    settings.seedRatio.toInt(),
                    (value) {
                      settings.setSeedRatio(value.toDouble());
                      _markChanged();
                    },
                    min: 0,
                    max: 100,
                    suffix: '0 means unlimited',
                  ),
                  _buildNumberSetting(
                    'Seed time (minutes)',
                    settings.seedTime,
                    (value) {
                      settings.setSeedTime(value);
                      _markChanged();
                    },
                    min: 0,
                    max: 10080,
                    suffix: '0 means unlimited',
                  ),
                ],
                _buildTextFieldSetting(
                  'Excluded trackers',
                  settings.btExcludeTracker,
                  (value) {
                    settings.setBtExcludeTracker(value);
                    _markChanged();
                  },
                  helperText: 'Separate multiple trackers with commas',
                  maxLines: 2,
                ),
              ],
            ),
            _buildSectionHeader('Network', theme),
            _buildCard(
              theme: theme,
              children: [
                _buildTextFieldSetting(
                  'Global proxy',
                  settings.allProxy,
                  (value) {
                    settings.setAllProxy(value);
                    _markChanged();
                  },
                  helperText: 'Example: http://proxy:port',
                ),
                _buildTextFieldSetting(
                  'No-proxy hosts',
                  settings.noProxy,
                  (value) {
                    settings.setNoProxy(value);
                    _markChanged();
                  },
                  helperText: 'Separate multiple hosts with commas',
                ),
                _buildNumberSetting(
                  'DHT listen port',
                  settings.dhtListenPort,
                  (value) {
                    settings.setDhtListenPort(value);
                    _markChanged();
                  },
                  min: 1024,
                  max: 65535,
                ),
                _buildSwitchSetting('Enable DHT6', settings.enableDht6, (
                  value,
                ) {
                  settings.setEnableDht6(value);
                  _markChanged();
                }),
              ],
            ),
            _buildSectionHeader('Files', theme),
            _buildCard(
              theme: theme,
              children: [
                _buildSwitchSetting(
                  'Auto rename files',
                  settings.autoFileRenaming,
                  (value) {
                    settings.setAutoFileRenaming(value);
                    _markChanged();
                  },
                ),
                _buildSwitchSetting(
                  'Allow overwrite',
                  settings.allowOverwrite,
                  (value) {
                    settings.setAllowOverwrite(value);
                    _markChanged();
                  },
                ),
                _buildTextFieldSetting('User agent', settings.userAgent, (
                  value,
                ) {
                  settings.setUserAgent(value);
                  _markChanged();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildCard({
    required List<Widget> children,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: children
            .asMap()
            .entries
            .map(
              (entry) => Column(
                children: [
                  entry.value,
                  if (entry.key < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: colorScheme.outlineVariant,
                    ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSwitchSetting(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SwitchListTile(
      title: Text(title, style: theme.textTheme.bodyMedium),
      value: value,
      onChanged: onChanged,
      activeThumbColor: colorScheme.primary,
      activeTrackColor: colorScheme.primary.withValues(alpha: 0.3),
      inactiveThumbColor: colorScheme.onSurfaceVariant,
      inactiveTrackColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }

  Widget _buildNumberSetting(
    String title,
    int value,
    ValueChanged<int> onChanged, {
    int min = 0,
    int max = 100,
    String suffix = '',
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: suffix.isNotEmpty
          ? Text(
              suffix,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      trailing: SizedBox(
        width: 130,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove),
              iconSize: 20,
              tooltip: 'Decrease',
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Container(
              width: 50,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add),
              iconSize: 20,
              tooltip: 'Increase',
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }

  Widget _buildTextFieldSetting(
    String title,
    String initialValue,
    ValueChanged<String> onChanged, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String helperText = '',
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      title: Text(title, style: theme.textTheme.bodyMedium),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      subtitle: Padding(
        padding: const EdgeInsets.only(right: 0),
        child: TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          cursorColor: colorScheme.primary,
          decoration: InputDecoration(
            helperText: helperText,
            helperStyle: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          style: theme.textTheme.bodyMedium,
        ),
      ),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }

  Future<void> _saveSettings(Settings settings) async {
    setState(() {
      _isSaving = true;
    });

    await settings.saveAllSettings();

    setState(() {
      _hasChanges = false;
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAndApplySettings(Settings settings) async {
    setState(() {
      _isSaving = true;
    });

    await settings.saveAllSettings();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              fl.SizedLoading.medium,
              const SizedBox(width: 16),
              const Expanded(
                child: Text('Restarting the built-in instance, please wait...'),
              ),
            ],
          ),
        ),
      );
    }

    try {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final builtinInstance = instanceManager.getBuiltinInstance();
      if (builtinInstance == null) {
        throw Exception('Built-in instance is missing');
      }

      await instanceManager.disconnectInstance(builtinInstance);
      await Future.delayed(const Duration(milliseconds: 500));
      final refreshedBuiltinInstance =
          instanceManager.getBuiltinInstance() ?? builtinInstance;
      final success = await instanceManager.connectInstance(
        refreshedBuiltinInstance,
      );

      if (mounted) {
        Navigator.pop(context);

        if (success) {
          final settingsService = Provider.of<SettingsService>(
            context,
            listen: false,
          );
          final applied = await settingsService.applySettingsToBuiltin();

          setState(() {
            _hasChanges = false;
            _isSaving = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                applied
                    ? 'Settings saved and applied successfully'
                    : 'Settings saved and instance restarted, but applying settings via RPC failed',
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: applied ? null : Colors.orange,
            ),
          );
        } else {
          setState(() {
            _isSaving = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Settings were saved, but restarting the built-in instance failed',
              ),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settings were saved, but restarting the built-in instance failed: $e',
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBackConfirmationDialog(BuildContext context, Settings settings) {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this page?'),
        content: const Text(
          'You have unsaved changes. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveAndApplySettings(settings);
              if (mounted) {
                Navigator.pop(this.context);
              }
            },
            child: const Text('Save & Apply'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveSettings(settings);
              if (mounted) {
                Navigator.pop(this.context);
              }
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
