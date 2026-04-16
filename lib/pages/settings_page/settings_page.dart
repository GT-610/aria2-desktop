import 'dart:io';

import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n/l10n.dart';
import '../../models/settings.dart';
import '../../services/protocol_integration_service.dart';
import '../../utils/logging.dart';
import './components/appearance_dialog.dart';

enum _SettingsTab { global, system, maintenance, about }

class _SettingsSection {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with Loggable, SingleTickerProviderStateMixin {
  String _version = '';
  bool _isLoading = true;
  late final TabController _tabController = TabController(
    length: _SettingsTab.values.length,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      i('Loading settings in settings page');
      await Provider.of<Settings>(context, listen: false).loadSettings();
      i('Settings loaded successfully');
    } catch (err) {
      this.e('Failed to load settings', error: err);
      if (mounted) {
        _showErrorSnackBar(AppLocalizations.of(context)!.loadSettingsFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _version = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: fl.SizedLoading.medium));
    }

    final settings = Provider.of<Settings>(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        bottom: TabBar(
          controller: _tabController,
          dividerHeight: 0,
          tabAlignment: TabAlignment.center,
          isScrollable: true,
          tabs: _SettingsTab.values
              .map((tab) => Tab(text: _tabTitle(tab, l10n)))
              .toList(growable: false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildTabView([
              _buildBehaviorSection(settings, l10n),
              _buildAppearanceSection(settings, l10n),
            ]),
            _buildTabView([
              _buildDesktopShellSection(settings, l10n),
              if (Platform.isWindows) _buildProtocolSection(settings, l10n),
            ]),
            _buildTabView([
              _buildLogSection(settings, l10n),
              _buildMaintenanceSection(l10n),
            ]),
            _buildTabView([_buildAboutSection(l10n)]),
          ],
        ),
      ),
    );
  }

  String _tabTitle(_SettingsTab tab, AppLocalizations l10n) {
    switch (tab) {
      case _SettingsTab.global:
        return l10n.globalSettings;
      case _SettingsTab.system:
        return l10n.systemIntegration;
      case _SettingsTab.maintenance:
        return l10n.maintenance;
      case _SettingsTab.about:
        return l10n.about;
    }
  }

  Widget _buildTabView(List<_SettingsSection> sections) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1440
            ? 3
            : width >= 900
            ? 2
            : 1;
        const gap = 16.0;
        final itemWidth = columns == 1
            ? width
            : (width - (gap * (columns - 1))) / columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: sections
                .map(
                  (section) => SizedBox(
                    width: itemWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        fl.CenterGreyTitle(section.title),
                        section.child,
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Column(children: children.map((child) => child).toList());
  }

  _SettingsSection _buildBehaviorSection(
    Settings settings,
    AppLocalizations l10n,
  ) {
    return _SettingsSection(
      title: l10n.globalSettings,
      child: _buildSettingsGroup([
        _buildSwitchTile(
          title: l10n.taskNotification,
          subtitle: l10n.taskNotificationTip,
          value: settings.taskNotification,
          onChanged: (value) => settings.setTaskNotification(value),
        ),
        _buildSwitchTile(
          title: l10n.skipDeleteConfirm,
          subtitle: l10n.skipDeleteConfirmTip,
          value: settings.skipDeleteConfirm,
          onChanged: (value) => settings.setSkipDeleteConfirm(value),
        ),
        _buildSwitchTile(
          title: l10n.resumeAllOnLaunch,
          subtitle: l10n.resumeAllOnLaunchTip,
          value: settings.resumeAllOnLaunch,
          onChanged: (value) => settings.setResumeAllOnLaunch(value),
        ),
        _buildSwitchTile(
          title: l10n.showDownloadsAfterAdd,
          subtitle: l10n.showDownloadsAfterAddTip,
          value: settings.showDownloadsAfterAdd,
          onChanged: (value) => settings.setShowDownloadsAfterAdd(value),
        ),
        _buildSwitchTile(
          title: l10n.showProgressBar,
          subtitle: l10n.showProgressBarTip,
          value: settings.showProgressBar,
          onChanged: (value) => settings.setShowProgressBar(value),
        ),
      ]),
    );
  }

  _SettingsSection _buildAppearanceSection(
    Settings settings,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _SettingsSection(
      title: l10n.appearance,
      child: _buildSettingsGroup([
        _buildTextCardTile(
          title: l10n.appearance,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: settings.primaryColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outline),
                ),
              ),
              Text(
                settings.themeMode.name == 'light'
                    ? l10n.light
                    : settings.themeMode.name == 'dark'
                    ? l10n.dark
                    : l10n.system,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => _showAppearanceDialog(context, settings),
        ),
        _buildTextCardTile(
          title: l10n.language,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_getLanguageName(settings.locale, l10n)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => _showLanguageDialog(context, settings, l10n),
        ),
      ]),
    );
  }

  _SettingsSection _buildDesktopShellSection(
    Settings settings,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    return _SettingsSection(
      title: l10n.systemIntegration,
      child: _buildSettingsGroup([
        _buildSwitchTile(
          title: l10n.runAtStartup,
          subtitle: l10n.runAtStartupTip,
          value: settings.autoStart,
          onChanged: (value) => settings.setAutoStart(value),
        ),
        fl.CardX(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(l10n.runMode, style: theme.textTheme.bodyLarge),
                  subtitle: Text(
                    _runModeDescription(settings.runMode, l10n),
                    style: fl.UIs.textGrey,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<AppRunMode>(
                      segments: [
                        ButtonSegment(
                          value: AppRunMode.standard,
                          label: Text(l10n.runModeStandard),
                        ),
                        ButtonSegment(
                          value: AppRunMode.tray,
                          label: Text(l10n.runModeTray),
                        ),
                        ButtonSegment(
                          value: AppRunMode.hideTray,
                          label: Text(l10n.runModeHideTray),
                        ),
                      ],
                      selected: {settings.runMode},
                      onSelectionChanged: (selection) async {
                        if (selection.isEmpty) {
                          return;
                        }
                        await _runSettingAction(
                          () => settings.setRunMode(selection.first),
                          l10n.saveSettingsFailed,
                          successLog:
                              'Run mode setting changed to: ${selection.first.name}',
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildSwitchTile(
          title: l10n.autoHideWindow,
          subtitle: l10n.autoHideWindowTip,
          value: settings.autoHideWindow,
          enabled: settings.runMode != AppRunMode.hideTray,
          onChanged: (value) => settings.setAutoHideWindow(value),
        ),
        _buildSwitchTile(
          title: l10n.showTraySpeed,
          subtitle: l10n.showTraySpeedTip,
          value: settings.showTraySpeed,
          enabled: settings.runMode != AppRunMode.hideTray,
          onChanged: (value) => settings.setShowTraySpeed(value),
        ),
      ]),
    );
  }

  _SettingsSection _buildProtocolSection(
    Settings settings,
    AppLocalizations l10n,
  ) {
    return _SettingsSection(
      title: l10n.setAsDefaultClient,
      child: _buildSettingsGroup([
        _buildTextCardTile(title: l10n.setAsDefaultClient),
        _buildSwitchTile(
          title: l10n.handleMagnetLinks,
          subtitle: l10n.handleMagnetLinksTip,
          value: settings.protocolMagnetEnabled,
          onChanged: (value) => _setProtocolPreference(
            scheme: 'magnet',
            protocolLabel: 'magnet://',
            value: value,
            persist: settings.setProtocolMagnetEnabled,
          ),
        ),
        _buildSwitchTile(
          title: l10n.handleThunderLinks,
          subtitle: l10n.handleThunderLinksTip,
          value: settings.protocolThunderEnabled,
          onChanged: (value) => _setProtocolPreference(
            scheme: 'thunder',
            protocolLabel: 'thunder://',
            value: value,
            persist: settings.setProtocolThunderEnabled,
          ),
        ),
      ]),
    );
  }

  _SettingsSection _buildLogSection(Settings settings, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _SettingsSection(
      title: l10n.logSettings,
      child: _buildSettingsGroup([
        fl.CardX(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              title: Text(l10n.logLevel, style: theme.textTheme.bodyLarge),
              trailing: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'debug', label: Text(l10n.debug)),
                  ButtonSegment(value: 'info', label: Text(l10n.info)),
                  ButtonSegment(value: 'warning', label: Text(l10n.warning)),
                  ButtonSegment(value: 'error', label: Text(l10n.error)),
                ],
                selected: {settings.logLevelString},
                onSelectionChanged: (newSelection) async {
                  if (newSelection.isEmpty) {
                    return;
                  }
                  final value = newSelection.first;
                  await _runSettingAction(
                    () async {
                      final logLevel = AppLogLevel.values.firstWhere(
                        (e) => e.name == value,
                      );
                      await settings.setAppLogLevel(logLevel);
                    },
                    l10n.saveSettingsFailed,
                    successLog: 'Log level changed to: $value',
                  );
                },
                style: SegmentedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        _buildSwitchTile(
          title: l10n.saveLogToFile,
          value: settings.saveLogsToFile,
          onChanged: (value) => settings.setSaveLogsToFile(value),
        ),
        fl.CardX(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _openLogDirectory,
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.viewLogFiles),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  _SettingsSection _buildMaintenanceSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _SettingsSection(
      title: l10n.maintenance,
      child: _buildSettingsGroup([
        _buildTextCardTile(
          title: l10n.viewLogFiles,
          trailing: const Icon(Icons.folder_open),
          onTap: _openLogDirectory,
        ),
        _buildWidgetCardTile(
          title: Text(
            l10n.resetAppSettings,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.error,
            ),
          ),
          subtitle: Text(l10n.resetAppSettingsTip),
          trailing: Icon(Icons.restart_alt, color: colorScheme.error),
          onTap: _confirmResetSettings,
        ),
      ]),
    );
  }

  _SettingsSection _buildAboutSection(AppLocalizations l10n) {
    return _SettingsSection(
      title: l10n.about,
      child: _buildSettingsGroup([
        _buildTextCardTile(
          title: l10n.version,
          subtitle: Text(_version.isEmpty ? l10n.versionLoading : _version),
        ),
        _buildTextCardTile(
          title: l10n.contributors,
          trailing: const Icon(Icons.chevron_right),
        ),
        _buildTextCardTile(
          title: l10n.license,
          trailing: const Icon(Icons.chevron_right),
        ),
      ]),
    );
  }

  Widget _buildWidgetCardTile({
    required Widget title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return fl.CardX(
      child: ListTile(
        title: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyLarge,
          child: title,
        ),
        subtitle: subtitle == null
            ? null
            : DefaultTextStyle.merge(style: fl.UIs.textGrey, child: subtitle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildTextCardTile({
    required String title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return _buildWidgetCardTile(
      title: Text(title),
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required Future<void> Function(bool value) onChanged,
    bool enabled = true,
  }) {
    return fl.CardX(
      child: ListTile(
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, style: fl.UIs.textGrey),
        trailing: Switch.adaptive(
          value: value,
          onChanged: !enabled
              ? null
              : (next) => _runSettingAction(
                  () => onChanged(next),
                  AppLocalizations.of(context)!.saveSettingsFailed,
                  successLog: '$title changed to: $next',
                ),
        ),
      ),
    );
  }

  Future<void> _runSettingAction(
    Future<void> Function() action,
    String errorMessage, {
    String? successLog,
  }) async {
    try {
      await action();
      if (successLog != null) {
        i(successLog);
      }
    } catch (e, stackTrace) {
      this.e('Failed to update setting', error: e, stackTrace: stackTrace);
      _showErrorSnackBar(errorMessage);
    }
  }

  void _showAppearanceDialog(BuildContext context, Settings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return AppearanceDialog(settings: settings);
      },
    );
  }

  String _getLanguageName(Locale? locale, AppLocalizations l10n) {
    if (locale == null) {
      return l10n.system;
    }
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'zh':
        return '中文';
      default:
        return locale.languageCode;
    }
  }

  String _runModeDescription(AppRunMode runMode, AppLocalizations l10n) {
    switch (runMode) {
      case AppRunMode.standard:
        return l10n.runModeStandardTip;
      case AppRunMode.tray:
        return l10n.runModeTrayTip;
      case AppRunMode.hideTray:
        return l10n.runModeHideTrayTip;
    }
  }

  void _showLanguageDialog(
    BuildContext context,
    Settings settings,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.language),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.system),
                trailing: settings.locale == null
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  settings.setLocale(null);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(l10n.english),
                trailing: settings.locale?.languageCode == 'en'
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  settings.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(l10n.chinese),
                trailing: settings.locale?.languageCode == 'zh'
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  settings.setLocale(const Locale('zh'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setProtocolPreference({
    required String scheme,
    required String protocolLabel,
    required bool value,
    required Future<void> Function(bool value) persist,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await persist(value);
    } catch (e) {
      this.e('Failed to save protocol preference for $scheme', error: e);
      _showErrorSnackBar(l10n.saveSettingsFailed);
      return;
    }

    try {
      await ProtocolIntegrationService().setProtocolEnabled(scheme, value);
      i('Protocol preference updated: $scheme enabled=$value');
    } catch (e, stackTrace) {
      this.w(
        'Failed to apply protocol preference for $scheme immediately',
        error: e,
        stackTrace: stackTrace,
      );
      _showWarningSnackBar(l10n.protocolPreferenceRetryWarning(protocolLabel));
    }
  }

  Future<void> _openLogDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = Provider.of<Settings>(context, listen: false);
    final logDirectory = Directory(settings.effectiveBuiltinLogDirectoryPath);
    if (!logDirectory.existsSync()) {
      _showErrorSnackBar(l10n.cannotOpenLogDirectory);
      return;
    }

    try {
      i('Opening log directory: ${logDirectory.path}');
      await Process.start(
        Platform.isWindows
            ? 'explorer.exe'
            : Platform.isLinux
            ? 'xdg-open'
            : 'open',
        [logDirectory.path],
      );
    } catch (e, stackTrace) {
      this.e('Failed to open log directory', error: e, stackTrace: stackTrace);
      _showErrorSnackBar(l10n.cannotOpenLogDirectory);
    }
  }

  Future<void> _confirmResetSettings() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.resetAppSettings),
          content: Text(l10n.resetAppSettingsConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.resetAppSettingsAction),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final settings = Provider.of<Settings>(context, listen: false);
    try {
      await settings.resetToDefaults();
      final failedProtocols = await ProtocolIntegrationService()
          .reconcileProtocolPreferences(settings);
      if (!mounted) {
        return;
      }

      if (failedProtocols.isNotEmpty) {
        _showWarningSnackBar(
          l10n.protocolReconcileFailed(failedProtocols.join(', ')),
        );
      } else {
        _showInfoSnackBar(l10n.resetAppSettingsSuccess);
      }
      i('Application settings reset to defaults');
    } catch (e, stackTrace) {
      this.e(
        'Failed to reset application settings',
        error: e,
        stackTrace: stackTrace,
      );
      _showErrorSnackBar(l10n.saveSettingsFailed);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showInfoSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showWarningSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
