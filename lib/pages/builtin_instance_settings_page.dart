import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../generated/l10n/l10n.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final settings = Provider.of<Settings>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.instanceSettings),
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
              l10n.save,
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
                    l10n.saveAndApply,
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
            _buildSectionHeader(l10n.connectionSection, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildTextFieldSetting(
                  l10n.rpcListenPort,
                  settings.rpcListenPort.toString(),
                  (value) {
                    settings.setRpcListenPort(int.tryParse(value) ?? 16800);
                    _markChanged();
                  },
                  keyboardType: TextInputType.number,
                  helperText: l10n.rpcPortDefault,
                ),
                _buildTextFieldSetting(
                  l10n.rpcSecret,
                  settings.rpcSecret,
                  (value) {
                    settings.setRpcSecret(value);
                    _markChanged();
                  },
                  obscureText: true,
                  helperText: l10n.leaveEmptyToDisableSecretAuth,
                ),
              ],
            ),
            _buildSectionHeader(l10n.transferSection, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildNumberSetting(
                  l10n.maxConcurrentDownloads,
                  settings.maxConcurrentDownloads,
                  (value) {
                    settings.setMaxConcurrentDownloads(value);
                    _markChanged();
                  },
                  min: 1,
                  max: 16,
                ),
                _buildNumberSetting(
                  l10n.maxConnectionPerServer,
                  settings.maxConnectionPerServer,
                  (value) {
                    settings.setMaxConnectionPerServer(value);
                    _markChanged();
                  },
                  min: 1,
                  max: 128,
                ),
                _buildNumberSetting(
                  l10n.splitCount,
                  settings.split,
                  (value) {
                    settings.setSplit(value);
                    _markChanged();
                  },
                  min: 1,
                  max: 128,
                ),
                _buildSwitchSetting(
                  l10n.continueUnfinishedDownloads,
                  settings.continueDownloads,
                  (value) {
                    settings.setContinueDownloads(value);
                    _markChanged();
                  },
                ),
              ],
            ),
            _buildSectionHeader(l10n.speedLimits, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildNumberSetting(
                  l10n.maxOverallDownloadLimit,
                  settings.maxOverallDownloadLimit,
                  (value) {
                    settings.setMaxOverallDownloadLimit(value);
                    _markChanged();
                  },
                  min: 0,
                  max: 65535,
                  suffix: l10n.downloadLimitTip,
                ),
                _buildNumberSetting(
                  l10n.maxOverallUploadLimit,
                  settings.maxOverallUploadLimit,
                  (value) {
                    settings.setMaxOverallUploadLimit(value);
                    _markChanged();
                  },
                  min: 0,
                  max: 65535,
                  suffix: l10n.uploadLimitTip,
                ),
              ],
            ),
            _buildSectionHeader(l10n.btPtSection, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildSwitchSetting(
                  l10n.saveBtMetadata,
                  settings.btSaveMetadata,
                  (value) {
                    settings.setBtSaveMetadata(value);
                    _markChanged();
                  },
                ),
                _buildSwitchSetting(
                  l10n.loadSavedBtMetadata,
                  settings.btLoadSavedMetadata,
                  (value) {
                    settings.setBtLoadSavedMetadata(value);
                    _markChanged();
                  },
                ),
                _buildSwitchSetting(
                  l10n.forceBtEncryption,
                  settings.btForceEncryption,
                  (value) {
                    settings.setBtForceEncryption(value);
                    _markChanged();
                  },
                ),
                _buildSwitchSetting(
                  l10n.keepSeedingAfterCompletion,
                  settings.keepSeeding,
                  (value) {
                    settings.setKeepSeeding(value);
                    _markChanged();
                  },
                ),
                if (!settings.keepSeeding) ...[
                  _buildNumberSetting(
                    l10n.seedRatio,
                    settings.seedRatio.toInt(),
                    (value) {
                      settings.setSeedRatio(value.toDouble());
                      _markChanged();
                    },
                    min: 0,
                    max: 100,
                    suffix: l10n.seedingRatioTip,
                  ),
                  _buildNumberSetting(
                    l10n.seedTimeMinutes,
                    settings.seedTime,
                    (value) {
                      settings.setSeedTime(value);
                      _markChanged();
                    },
                    min: 0,
                    max: 10080,
                    suffix: l10n.seedingTimeTip,
                  ),
                ],
                _buildTextFieldSetting(
                  l10n.excludedTrackers,
                  settings.btExcludeTracker,
                  (value) {
                    settings.setBtExcludeTracker(value);
                    _markChanged();
                  },
                  helperText: l10n.trackersTip,
                  maxLines: 2,
                ),
              ],
            ),
            _buildSectionHeader(l10n.networkSection, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildTextFieldSetting(l10n.globalProxy, settings.allProxy, (
                  value,
                ) {
                  settings.setAllProxy(value);
                  _markChanged();
                }, helperText: l10n.exampleProxy),
                _buildTextFieldSetting(
                  l10n.noProxyHosts,
                  settings.noProxy,
                  (value) {
                    settings.setNoProxy(value);
                    _markChanged();
                  },
                  helperText: l10n.multipleHostsComma,
                ),
                _buildNumberSetting(
                  l10n.dhtListenPort,
                  settings.dhtListenPort,
                  (value) {
                    settings.setDhtListenPort(value);
                    _markChanged();
                  },
                  min: 1024,
                  max: 65535,
                ),
                _buildSwitchSetting(l10n.enableDht6, settings.enableDht6, (
                  value,
                ) {
                  settings.setEnableDht6(value);
                  _markChanged();
                }),
              ],
            ),
            _buildSectionHeader(l10n.filesSection, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildSwitchSetting(
                  l10n.autoRenameFiles,
                  settings.autoFileRenaming,
                  (value) {
                    settings.setAutoFileRenaming(value);
                    _markChanged();
                  },
                ),
                _buildSwitchSetting(
                  l10n.allowOverwrite,
                  settings.allowOverwrite,
                  (value) {
                    settings.setAllowOverwrite(value);
                    _markChanged();
                  },
                ),
                _buildTextFieldSetting(l10n.userAgent, settings.userAgent, (
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
              tooltip: AppLocalizations.of(context)!.decrease,
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
              tooltip: AppLocalizations.of(context)!.increase,
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
    final l10n = AppLocalizations.of(context)!;
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
        SnackBar(
          content: Text(l10n.settingsSaved),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAndApplySettings(Settings settings) async {
    final l10n = AppLocalizations.of(context)!;
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
              Expanded(child: Text(l10n.restartingBuiltinInstance)),
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
        throw Exception(l10n.builtinInstanceMissing);
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
          if (!mounted) {
            return;
          }

          setState(() {
            _hasChanges = false;
            _isSaving = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                applied
                    ? l10n.settingsSavedAppliedSuccess
                    : l10n.settingsSavedRpcApplyFailed,
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
            SnackBar(
              content: Text(l10n.settingsSavedRestartFailed),
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
            content: Text(l10n.settingsSavedRestartFailedWithError('$e')),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBackConfirmationDialog(BuildContext context, Settings settings) {
    final l10n = AppLocalizations.of(context)!;
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leavePage),
        content: Text(l10n.unsavedChangesPrompt),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveAndApplySettings(settings);
              if (mounted) {
                Navigator.pop(this.context);
              }
            },
            child: Text(l10n.saveAndApply),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveSettings(settings);
              if (mounted) {
                Navigator.pop(this.context);
              }
            },
            child: Text(l10n.save),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
            child: Text(l10n.discard),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }
}
