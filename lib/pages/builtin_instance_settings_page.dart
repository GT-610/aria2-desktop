import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../generated/l10n/l10n.dart';
import '../models/aria2_instance.dart';
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
  bool _didInitializeDraft = false;

  late int _rpcListenPort;
  late String _rpcSecret;
  late int _maxConcurrentDownloads;
  late int _maxConnectionPerServer;
  late int _split;
  late bool _continueDownloads;
  late int _maxOverallDownloadLimit;
  late int _maxOverallUploadLimit;
  late bool _btSaveMetadata;
  late bool _btLoadSavedMetadata;
  late bool _btForceEncryption;
  late bool _keepSeeding;
  late double _seedRatio;
  late int _seedTime;
  late String _btListenPort;
  late String _btExcludeTracker;
  late bool _proxyEnabled;
  late String _allProxy;
  late String _noProxy;
  late int _dhtListenPort;
  late bool _enableDht6;
  late bool _autoFileRenaming;
  late bool _allowOverwrite;
  late String _userAgent;

  final TextEditingController _rpcSecretController = TextEditingController();
  final TextEditingController _btListenPortController = TextEditingController();
  final TextEditingController _excludedTrackersController =
      TextEditingController();
  final TextEditingController _allProxyController = TextEditingController();
  final TextEditingController _noProxyController = TextEditingController();
  final TextEditingController _userAgentController = TextEditingController();

  _BuiltinSettingsApplyMode _currentApplyMode(Settings settings) {
    if (_hasRestartRequiredSettingChanges(settings)) {
      return _BuiltinSettingsApplyMode.restartRequired;
    }
    if (_hasLiveApplySettingChanges(settings)) {
      return _BuiltinSettingsApplyMode.liveApply;
    }
    return _BuiltinSettingsApplyMode.none;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeDraft) {
      return;
    }

    final settings = Provider.of<Settings>(context, listen: false);
    _rpcListenPort = settings.rpcListenPort;
    _rpcSecret = settings.rpcSecret;
    _maxConcurrentDownloads = settings.maxConcurrentDownloads;
    _maxConnectionPerServer = settings.maxConnectionPerServer;
    _split = settings.split;
    _continueDownloads = settings.continueDownloads;
    _maxOverallDownloadLimit = settings.maxOverallDownloadLimit;
    _maxOverallUploadLimit = settings.maxOverallUploadLimit;
    _btSaveMetadata = settings.btSaveMetadata;
    _btLoadSavedMetadata = settings.btLoadSavedMetadata;
    _btForceEncryption = settings.btForceEncryption;
    _keepSeeding = settings.keepSeeding;
    _seedRatio = settings.seedRatio;
    _seedTime = settings.seedTime;
    _btListenPort = settings.btListenPort;
    _btExcludeTracker = settings.btExcludeTracker;
    _proxyEnabled = settings.proxyEnabled;
    _allProxy = settings.allProxy;
    _noProxy = settings.noProxy;
    _dhtListenPort = settings.dhtListenPort;
    _enableDht6 = settings.enableDht6;
    _autoFileRenaming = settings.autoFileRenaming;
    _allowOverwrite = settings.allowOverwrite;
    _userAgent = settings.userAgent;

    _rpcSecretController.text = _rpcSecret;
    _btListenPortController.text = _btListenPort;
    _excludedTrackersController.text = _btExcludeTracker;
    _allProxyController.text = _allProxy;
    _noProxyController.text = _noProxy;
    _userAgentController.text = _userAgent;
    _didInitializeDraft = true;
  }

  @override
  void dispose() {
    _rpcSecretController.dispose();
    _btListenPortController.dispose();
    _excludedTrackersController.dispose();
    _allProxyController.dispose();
    _noProxyController.dispose();
    _userAgentController.dispose();
    super.dispose();
  }

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
            _buildApplyHintCard(settings, theme),
            _buildSectionHeader(l10n.connectionSection, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildTextFieldSetting(
                  l10n.rpcListenPort,
                  _rpcListenPort.toString(),
                  (value) {
                    _updateDraft(
                      () => _rpcListenPort = int.tryParse(value) ?? 16800,
                    );
                  },
                  keyboardType: TextInputType.number,
                  helperText: l10n.rpcPortDefault,
                ),
                _buildTextFieldSetting(
                  l10n.rpcSecret,
                  _rpcSecret,
                  (value) {
                    _updateDraft(() => _rpcSecret = value);
                  },
                  obscureText: true,
                  helperText: l10n.leaveEmptyToDisableSecretAuth,
                  controller: _rpcSecretController,
                ),
              ],
            ),
            _buildSectionHeader(l10n.transferSection, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildNumberSetting(
                  l10n.maxConcurrentDownloads,
                  _maxConcurrentDownloads,
                  (value) {
                    _updateDraft(() => _maxConcurrentDownloads = value);
                  },
                  min: 1,
                  max: 16,
                ),
                _buildNumberSetting(
                  l10n.maxConnectionPerServer,
                  _maxConnectionPerServer,
                  (value) {
                    _updateDraft(() => _maxConnectionPerServer = value);
                  },
                  min: 1,
                  max: 128,
                ),
                _buildNumberSetting(
                  l10n.splitCount,
                  _split,
                  (value) {
                    _updateDraft(() => _split = value);
                  },
                  min: 1,
                  max: 128,
                ),
                _buildSwitchSetting(
                  l10n.continueUnfinishedDownloads,
                  _continueDownloads,
                  (value) {
                    _updateDraft(() => _continueDownloads = value);
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
                  _maxOverallDownloadLimit,
                  (value) {
                    _updateDraft(() => _maxOverallDownloadLimit = value);
                  },
                  min: 0,
                  max: 65535,
                  suffix: l10n.downloadLimitTip,
                ),
                _buildNumberSetting(
                  l10n.maxOverallUploadLimit,
                  _maxOverallUploadLimit,
                  (value) {
                    _updateDraft(() => _maxOverallUploadLimit = value);
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
                _buildSwitchSetting(l10n.saveBtMetadata, _btSaveMetadata, (
                  value,
                ) {
                  _updateDraft(() => _btSaveMetadata = value);
                }),
                _buildSwitchSetting(
                  l10n.loadSavedBtMetadata,
                  _btLoadSavedMetadata,
                  (value) {
                    _updateDraft(() => _btLoadSavedMetadata = value);
                  },
                ),
                _buildSwitchSetting(
                  l10n.forceBtEncryption,
                  _btForceEncryption,
                  (value) {
                    _updateDraft(() => _btForceEncryption = value);
                  },
                ),
                _buildSwitchSetting(
                  l10n.keepSeedingAfterCompletion,
                  _keepSeeding,
                  (value) {
                    _updateDraft(() => _keepSeeding = value);
                  },
                ),
                if (!_keepSeeding) ...[
                  _buildNumberSetting(
                    l10n.seedRatio,
                    _seedRatio.toInt(),
                    (value) {
                      _updateDraft(() => _seedRatio = value.toDouble());
                    },
                    min: 0,
                    max: 100,
                    suffix: l10n.seedingRatioTip,
                  ),
                  _buildNumberSetting(
                    l10n.seedTimeMinutes,
                    _seedTime,
                    (value) {
                      _updateDraft(() => _seedTime = value);
                    },
                    min: 0,
                    max: 10080,
                    suffix: l10n.seedingTimeTip,
                  ),
                ],
                _buildTextFieldSetting(
                  l10n.btListenPort,
                  _btListenPort,
                  (value) {
                    _updateDraft(() => _btListenPort = value.trim());
                  },
                  helperText: l10n.btListenPortTip,
                  controller: _btListenPortController,
                ),
                _buildTextFieldSetting(
                  l10n.excludedTrackers,
                  _btExcludeTracker,
                  (value) {
                    _updateDraft(() => _btExcludeTracker = value);
                  },
                  helperText: l10n.trackersTip,
                  maxLines: 2,
                  controller: _excludedTrackersController,
                ),
              ],
            ),
            _buildSectionHeader(l10n.networkSection, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildSwitchSetting(l10n.enableProxy, _proxyEnabled, (value) {
                  _updateDraft(() => _proxyEnabled = value);
                }, helperText: l10n.enableProxyTip),
                _buildTextFieldSetting(
                  l10n.globalProxy,
                  _allProxy,
                  (value) {
                    _updateDraft(() => _allProxy = value);
                  },
                  helperText: l10n.exampleProxy,
                  controller: _allProxyController,
                  enabled: _proxyEnabled,
                ),
                _buildTextFieldSetting(
                  l10n.noProxyHosts,
                  _noProxy,
                  (value) {
                    _updateDraft(() => _noProxy = value);
                  },
                  helperText: l10n.multipleHostsComma,
                  controller: _noProxyController,
                  enabled: _proxyEnabled,
                ),
                _buildNumberSetting(
                  l10n.dhtListenPort,
                  _dhtListenPort,
                  (value) {
                    _updateDraft(() => _dhtListenPort = value);
                  },
                  min: 1024,
                  max: 65535,
                ),
                _buildSwitchSetting(l10n.enableDht6, _enableDht6, (value) {
                  _updateDraft(() => _enableDht6 = value);
                }),
              ],
            ),
            _buildSectionHeader(l10n.filesSection, theme),
            _buildCard(
              theme: theme,
              children: [
                _buildSwitchSetting(l10n.autoRenameFiles, _autoFileRenaming, (
                  value,
                ) {
                  _updateDraft(() => _autoFileRenaming = value);
                }),
                _buildSwitchSetting(l10n.allowOverwrite, _allowOverwrite, (
                  value,
                ) {
                  _updateDraft(() => _allowOverwrite = value);
                }),
                _buildTextFieldSetting(l10n.userAgent, _userAgent, (value) {
                  _updateDraft(() => _userAgent = value);
                }, controller: _userAgentController),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateDraft(VoidCallback update) {
    setState(() {
      update();
      _hasChanges = true;
    });
  }

  bool _hasRestartRequiredSettingChanges(Settings settings) {
    return _rpcListenPort != settings.rpcListenPort ||
        _rpcSecret != settings.rpcSecret ||
        _btLoadSavedMetadata != settings.btLoadSavedMetadata ||
        _btListenPort != settings.btListenPort ||
        _dhtListenPort != settings.dhtListenPort ||
        _enableDht6 != settings.enableDht6;
  }

  bool _hasLiveApplySettingChanges(Settings settings) {
    return _maxOverallDownloadLimit != settings.maxOverallDownloadLimit ||
        _maxOverallUploadLimit != settings.maxOverallUploadLimit ||
        _maxConcurrentDownloads != settings.maxConcurrentDownloads ||
        _maxConnectionPerServer != settings.maxConnectionPerServer ||
        _split != settings.split ||
        _continueDownloads != settings.continueDownloads ||
        _btSaveMetadata != settings.btSaveMetadata ||
        _btForceEncryption != settings.btForceEncryption ||
        _keepSeeding != settings.keepSeeding ||
        _seedRatio != settings.seedRatio ||
        _seedTime != settings.seedTime ||
        _btExcludeTracker != settings.btExcludeTracker ||
        _proxyEnabled != settings.proxyEnabled ||
        _allProxy != settings.allProxy ||
        _noProxy != settings.noProxy ||
        _autoFileRenaming != settings.autoFileRenaming ||
        _allowOverwrite != settings.allowOverwrite ||
        _userAgent != settings.userAgent;
  }

  Future<void> _persistDraft(Settings settings) {
    return settings.updateBuiltinInstanceSettings(
      rpcListenPort: _rpcListenPort,
      rpcSecret: _rpcSecret,
      maxConcurrentDownloads: _maxConcurrentDownloads,
      maxConnectionPerServer: _maxConnectionPerServer,
      split: _split,
      continueDownloads: _continueDownloads,
      maxOverallDownloadLimit: _maxOverallDownloadLimit,
      maxOverallUploadLimit: _maxOverallUploadLimit,
      btSaveMetadata: _btSaveMetadata,
      btForceEncryption: _btForceEncryption,
      btLoadSavedMetadata: _btLoadSavedMetadata,
      keepSeeding: _keepSeeding,
      seedRatio: _seedRatio,
      seedTime: _seedTime,
      btListenPort: _btListenPort,
      btExcludeTracker: _btExcludeTracker,
      proxyEnabled: _proxyEnabled,
      allProxy: _allProxy,
      noProxy: _noProxy,
      dhtListenPort: _dhtListenPort,
      enableDht6: _enableDht6,
      autoFileRenaming: _autoFileRenaming,
      allowOverwrite: _allowOverwrite,
      userAgent: _userAgent,
    );
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
    ValueChanged<bool> onChanged, {
    String helperText = '',
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SwitchListTile(
      title: Text(title, style: theme.textTheme.bodyMedium),
      subtitle: helperText.isNotEmpty
          ? Text(
              helperText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
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
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String helperText = '',
    int maxLines = 1,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      title: Text(title, style: theme.textTheme.bodyMedium),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      subtitle: Padding(
        padding: const EdgeInsets.only(right: 0),
        child: TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          onChanged: onChanged,
          enabled: enabled,
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

    await _persistDraft(settings);

    setState(() {
      _hasChanges = false;
      _isSaving = false;
    });

    _showSettingsSnackBar(AppLocalizations.of(context)!.settingsSaved);
  }

  Future<void> _saveAndApplySettings(Settings settings) async {
    final l10n = AppLocalizations.of(context)!;
    final applyMode = _currentApplyMode(settings);

    setState(() {
      _isSaving = true;
    });

    await _persistDraft(settings);

    if (applyMode == _BuiltinSettingsApplyMode.none) {
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
      _showSettingsSnackBar(l10n.settingsSaved);
      return;
    }

    if (applyMode == _BuiltinSettingsApplyMode.liveApply) {
      final instanceManager = Provider.of<InstanceManager>(
        context,
        listen: false,
      );
      final builtinInstance = instanceManager.getBuiltinInstance();

      if (builtinInstance != null &&
          builtinInstance.status == ConnectionStatus.connected) {
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

        _showSettingsSnackBar(
          applied
              ? l10n.settingsSavedAppliedSuccess
              : l10n.settingsSavedRpcApplyFailed,
          backgroundColor: applied ? null : Colors.orange,
        );
        return;
      }

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
      _showSettingsSnackBar(
        l10n.settingsSavedApplyWhenConnected,
        backgroundColor: Colors.orange,
      );
      return;
    }

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
          setState(() {
            _hasChanges = false;
            _isSaving = false;
          });

          _showSettingsSnackBar(l10n.settingsSavedAppliedSuccess);
        } else {
          setState(() {
            _isSaving = false;
          });

          _showSettingsSnackBar(
            l10n.settingsSavedRestartFailed,
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() {
          _isSaving = false;
        });

        _showSettingsSnackBar(
          l10n.settingsSavedRestartFailedWithError('$e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _showSettingsSnackBar(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
      ),
    );
  }

  Widget _buildApplyHintCard(Settings settings, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final applyMode = _currentApplyMode(settings);
    final applyMessage = switch (applyMode) {
      _BuiltinSettingsApplyMode.liveApply => l10n.settingsApplyLiveHint,
      _BuiltinSettingsApplyMode.restartRequired =>
        l10n.settingsApplyRestartHint,
      _BuiltinSettingsApplyMode.none => l10n.settingsApplyNoPendingHint,
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            applyMode == _BuiltinSettingsApplyMode.restartRequired
                ? Icons.restart_alt
                : Icons.info_outline,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsSaveOnlyHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  applyMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

enum _BuiltinSettingsApplyMode { none, liveApply, restartRequired }
