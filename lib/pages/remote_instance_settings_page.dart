import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';

import '../generated/l10n/l10n.dart';
import '../models/aria2_instance.dart';
import '../services/aria2_rpc_client.dart';

class RemoteInstanceSettingsPage extends StatefulWidget {
  final Aria2Instance instance;

  const RemoteInstanceSettingsPage({super.key, required this.instance});

  @override
  State<RemoteInstanceSettingsPage> createState() =>
      _RemoteInstanceSettingsPageState();
}

class _RemoteInstanceSettingsPageState
    extends State<RemoteInstanceSettingsPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasLoaded = false;

  late final TextEditingController _downloadDirController;
  late final TextEditingController _btListenPortController;
  late final TextEditingController _seedRatioController;
  late final TextEditingController _trackerController;
  late final TextEditingController _excludedTrackerController;
  late final TextEditingController _allProxyController;
  late final TextEditingController _noProxyController;
  late final TextEditingController _userAgentController;

  int _maxConcurrentDownloads = 5;
  int _maxConnectionPerServer = 16;
  int _split = 5;
  bool _continueDownloads = true;
  int _maxOverallDownloadLimit = 0;
  int _maxOverallUploadLimit = 0;
  bool _btSaveMetadata = true;
  bool _btLoadSavedMetadata = true;
  bool _btRequireCrypto = false;
  int _seedTime = 0;
  int _dhtListenPort = 6801;
  bool _enableDht6 = true;

  String? _loadError;
  Map<String, String> _originalOptions = {};

  @override
  void initState() {
    super.initState();
    _downloadDirController = TextEditingController();
    _btListenPortController = TextEditingController();
    _seedRatioController = TextEditingController();
    _trackerController = TextEditingController();
    _excludedTrackerController = TextEditingController();
    _allProxyController = TextEditingController();
    _noProxyController = TextEditingController();
    _userAgentController = TextEditingController();
    _loadRemoteOptions();
  }

  @override
  void dispose() {
    _downloadDirController.dispose();
    _btListenPortController.dispose();
    _seedRatioController.dispose();
    _trackerController.dispose();
    _excludedTrackerController.dispose();
    _allProxyController.dispose();
    _noProxyController.dispose();
    _userAgentController.dispose();
    super.dispose();
  }

  Future<void> _loadRemoteOptions() async {
    final client = Aria2RpcClient(widget.instance);

    try {
      final options = await client.getGlobalOption();
      if (!mounted) {
        return;
      }

      final normalized = _normalizeOptions(options);
      setState(() {
        _originalOptions = normalized;
        _applyNormalizedOptions(normalized);
        _isLoading = false;
        _hasLoaded = true;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _hasLoaded = false;
        _loadError = '$error';
      });
    } finally {
      client.close();
    }
  }

  Map<String, String> _normalizeOptions(Map<String, dynamic> options) {
    final normalized = <String, String>{};
    for (final entry in options.entries) {
      normalized[entry.key] = entry.value?.toString() ?? '';
    }
    return normalized;
  }

  void _applyNormalizedOptions(Map<String, String> options) {
    _downloadDirController.text = options['dir'] ?? '';
    _maxConcurrentDownloads = _parseIntOption(
      options['max-concurrent-downloads'],
      fallback: 5,
      min: 1,
    );
    _maxConnectionPerServer = _parseIntOption(
      options['max-connection-per-server'],
      fallback: 16,
      min: 1,
    );
    _split = _parseIntOption(options['split'], fallback: 5, min: 1);
    _continueDownloads = _parseBoolOption(options['continue'], fallback: true);
    _maxOverallDownloadLimit = _parseSpeedLimitToKbps(
      options['max-overall-download-limit'],
    );
    _maxOverallUploadLimit = _parseSpeedLimitToKbps(
      options['max-overall-upload-limit'],
    );
    _btSaveMetadata = _parseBoolOption(
      options['bt-save-metadata'],
      fallback: true,
    );
    _btLoadSavedMetadata = _parseBoolOption(
      options['bt-load-saved-metadata'],
      fallback: true,
    );
    _btRequireCrypto = _parseBoolOption(
      options['bt-require-crypto'],
      fallback: false,
    );
    _seedTime = _parseIntOption(options['seed-time'], fallback: 0, min: 0);
    _seedRatioController.text = options['seed-ratio'] ?? '1.0';
    _btListenPortController.text = options['listen-port'] ?? '';
    _dhtListenPort = _parseIntOption(
      options['dht-listen-port'],
      fallback: 6801,
      min: 0,
    );
    _enableDht6 = _parseBoolOption(options['enable-dht6'], fallback: true);
    _trackerController.text = options['bt-tracker'] ?? '';
    _excludedTrackerController.text = options['bt-exclude-tracker'] ?? '';
    _allProxyController.text = options['all-proxy'] ?? '';
    _noProxyController.text = options['no-proxy'] ?? '';
    _userAgentController.text = options['user-agent'] ?? '';
  }

  int _parseIntOption(String? rawValue, {required int fallback, int min = 0}) {
    final parsed = int.tryParse((rawValue ?? '').trim());
    if (parsed == null) {
      return fallback;
    }
    return parsed < min ? fallback : parsed;
  }

  bool _parseBoolOption(String? rawValue, {required bool fallback}) {
    final value = (rawValue ?? '').trim().toLowerCase();
    if (value == 'true') {
      return true;
    }
    if (value == 'false') {
      return false;
    }
    return fallback;
  }

  int _parseSpeedLimitToKbps(String? rawValue) {
    final value = (rawValue ?? '').trim().toLowerCase();
    if (value.isEmpty || value == '0') {
      return 0;
    }
    if (value.endsWith('k')) {
      return int.tryParse(value.substring(0, value.length - 1)) ?? 0;
    }
    if (value.endsWith('m')) {
      final parsed = double.tryParse(value.substring(0, value.length - 1));
      return parsed == null ? 0 : (parsed * 1024).round();
    }

    final bytes = int.tryParse(value);
    if (bytes == null || bytes <= 0) {
      return 0;
    }
    return (bytes / 1024).ceil();
  }

  String _formatSpeedLimitOption(int value) {
    return value > 0 ? '${value}K' : '0';
  }

  Map<String, String> _buildCurrentOptions() {
    return {
      'dir': _downloadDirController.text.trim(),
      'max-concurrent-downloads': _maxConcurrentDownloads.toString(),
      'max-connection-per-server': _maxConnectionPerServer.toString(),
      'split': _split.toString(),
      'continue': _continueDownloads.toString(),
      'max-overall-download-limit': _formatSpeedLimitOption(
        _maxOverallDownloadLimit,
      ),
      'max-overall-upload-limit': _formatSpeedLimitOption(
        _maxOverallUploadLimit,
      ),
      'bt-save-metadata': _btSaveMetadata.toString(),
      'bt-load-saved-metadata': _btLoadSavedMetadata.toString(),
      'bt-require-crypto': _btRequireCrypto.toString(),
      'seed-time': _seedTime.toString(),
      'seed-ratio': _seedRatioController.text.trim().isEmpty
          ? '0'
          : _seedRatioController.text.trim(),
      'listen-port': _btListenPortController.text.trim(),
      'dht-listen-port': _dhtListenPort.toString(),
      'enable-dht6': _enableDht6.toString(),
      'bt-tracker': _trackerController.text.trim(),
      'bt-exclude-tracker': _excludedTrackerController.text.trim(),
      'all-proxy': _allProxyController.text.trim(),
      'no-proxy': _noProxyController.text.trim(),
      'user-agent': _userAgentController.text.trim(),
    };
  }

  Map<String, dynamic> _buildChangedOptions() {
    final current = _buildCurrentOptions();
    final changed = <String, dynamic>{};

    for (final entry in current.entries) {
      final originalValue = _originalOptions[entry.key] ?? '';
      if (entry.value != originalValue) {
        changed[entry.key] = entry.value;
      }
    }

    return changed;
  }

  String? _validateBeforeSave(AppLocalizations l10n) {
    if (_downloadDirController.text.trim().isEmpty) {
      return l10n.remoteSettingsDownloadDirRequired;
    }

    final seedRatio = _seedRatioController.text.trim();
    if (seedRatio.isNotEmpty && double.tryParse(seedRatio) == null) {
      return l10n.remoteSettingsInvalidSeedRatio;
    }

    final btListenPort = _btListenPortController.text.trim();
    if (btListenPort.isEmpty) {
      return l10n.remoteSettingsBtPortRequired;
    }

    return null;
  }

  Future<void> _saveRemoteSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final validationError = _validateBeforeSave(l10n);
    if (validationError != null) {
      _showSnackBar(validationError, backgroundColor: Colors.red);
      return;
    }

    final changedOptions = _buildChangedOptions();
    if (changedOptions.isEmpty) {
      _showSnackBar(l10n.remoteSettingsNoChanges);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final client = Aria2RpcClient(widget.instance);
    try {
      final result = await client.setGlobalOption(changedOptions);
      if (!mounted) {
        return;
      }

      if (!result) {
        _showSnackBar(
          l10n.remoteSettingsSaveFailed,
          backgroundColor: Colors.red,
        );
        return;
      }

      setState(() {
        _originalOptions = _buildCurrentOptions();
      });
      _showSnackBar(l10n.remoteSettingsSaved);
    } catch (error) {
      if (mounted) {
        _showSnackBar(
          l10n.remoteSettingsSaveFailedWithError('$error'),
          backgroundColor: Colors.red,
        );
      }
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.remoteAria2Settings),
        actions: [
          TextButton(
            onPressed: _isLoading || _isSaving || !_hasLoaded
                ? null
                : _saveRemoteSettings,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: fl.SizedLoading.small,
                  )
                : Text(l10n.save, style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
      body: _buildBody(theme, l10n),
    );
  }

  Widget _buildBody(ThemeData theme, AppLocalizations l10n) {
    if (widget.instance.status != ConnectionStatus.connected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.remoteSettingsRequiresConnectedInstance,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: fl.SizedLoading.medium);
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.remoteSettingsLoadFailedWithError(_loadError!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadRemoteOptions,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(theme, l10n),
          _buildSectionHeader(l10n.transferSection, theme),
          _buildCard(
            theme: theme,
            children: [
              _buildTextFieldSetting(
                l10n.defaultDownloadDir,
                controller: _downloadDirController,
                helperText: l10n.remoteDownloadDirHint,
              ),
              _buildNumberSetting(
                l10n.maxConcurrentDownloads,
                _maxConcurrentDownloads,
                (value) => setState(() => _maxConcurrentDownloads = value),
                min: 1,
                max: 64,
              ),
              _buildNumberSetting(
                l10n.maxConnectionPerServer,
                _maxConnectionPerServer,
                (value) => setState(() => _maxConnectionPerServer = value),
                min: 1,
                max: 64,
              ),
              _buildNumberSetting(
                l10n.splitCount,
                _split,
                (value) => setState(() => _split = value),
                min: 1,
                max: 128,
              ),
              _buildSwitchSetting(
                l10n.continueUnfinishedDownloads,
                _continueDownloads,
                (value) => setState(() => _continueDownloads = value),
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
                (value) => setState(() => _maxOverallDownloadLimit = value),
                min: 0,
                max: 1024 * 1024,
                suffix: l10n.downloadLimitTip,
              ),
              _buildNumberSetting(
                l10n.maxOverallUploadLimit,
                _maxOverallUploadLimit,
                (value) => setState(() => _maxOverallUploadLimit = value),
                min: 0,
                max: 1024 * 1024,
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
                _btSaveMetadata,
                (value) => setState(() => _btSaveMetadata = value),
              ),
              _buildSwitchSetting(
                l10n.loadSavedBtMetadata,
                _btLoadSavedMetadata,
                (value) => setState(() => _btLoadSavedMetadata = value),
              ),
              _buildSwitchSetting(
                l10n.forceBtEncryption,
                _btRequireCrypto,
                (value) => setState(() => _btRequireCrypto = value),
              ),
              _buildNumberSetting(
                l10n.seedTimeMinutes,
                _seedTime,
                (value) => setState(() => _seedTime = value),
                min: 0,
                max: 525600,
                suffix: l10n.seedingTimeTip,
              ),
              _buildTextFieldSetting(
                l10n.seedRatio,
                controller: _seedRatioController,
                helperText: l10n.seedingRatioTip,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              _buildTextFieldSetting(
                l10n.btListenPort,
                controller: _btListenPortController,
                helperText: l10n.btListenPortTip,
              ),
              _buildNumberSetting(
                l10n.dhtListenPort,
                _dhtListenPort,
                (value) => setState(() => _dhtListenPort = value),
                min: 0,
                max: 65535,
              ),
              _buildSwitchSetting(
                l10n.enableDht6,
                _enableDht6,
                (value) => setState(() => _enableDht6 = value),
              ),
              _buildTextFieldSetting(
                l10n.btTrackerServers,
                controller: _trackerController,
                helperText: l10n.btTrackerServersTip,
                maxLines: 4,
              ),
              _buildTextFieldSetting(
                l10n.excludedTrackers,
                controller: _excludedTrackerController,
                helperText: l10n.trackersTip,
                maxLines: 2,
              ),
            ],
          ),
          _buildSectionHeader(l10n.networkSection, theme),
          _buildCard(
            theme: theme,
            children: [
              _buildTextFieldSetting(
                l10n.globalProxy,
                controller: _allProxyController,
                helperText: l10n.exampleProxy,
              ),
              _buildTextFieldSetting(
                l10n.noProxyHosts,
                controller: _noProxyController,
                helperText: l10n.multipleHostsComma,
              ),
              _buildTextFieldSetting(
                l10n.userAgent,
                controller: _userAgentController,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.instance.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.instance.rpcUrl,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.remoteSettingsInfoTip,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
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
    required ThemeData theme,
    required List<Widget> children,
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
      onChanged: _isSaving ? null : onChanged,
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
    required int min,
    required int max,
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
              onPressed: _isSaving || value <= min
                  ? null
                  : () => onChanged(value - 1),
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
              onPressed: _isSaving || value >= max
                  ? null
                  : () => onChanged(value + 1),
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
    String title, {
    required TextEditingController controller,
    String helperText = '',
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      title: Text(title, style: theme.textTheme.bodyMedium),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: TextFormField(
          controller: controller,
          enabled: !_isSaving,
          keyboardType: keyboardType,
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
}
