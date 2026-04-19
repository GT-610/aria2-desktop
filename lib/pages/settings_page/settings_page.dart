import 'dart:io';

import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_branding.dart';
import '../../constants/github_id.dart';
import '../../generated/l10n/l10n.dart';
import '../../models/settings.dart';
import '../../services/protocol_integration_service.dart';
import '../../services/startup_integration_service.dart';
import '../../utils/logging.dart';
import './components/appearance_dialog.dart';

enum _SettingsTab { global, system, about }

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
    with
        AutomaticKeepAliveClientMixin,
        Loggable,
        SingleTickerProviderStateMixin {
  String _versionLabel = '';
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
      await Provider.of<Settings>(context, listen: false).loadSettings();
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
      _versionLabel = _formatVersionLabel(
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      );
    });
  }

  String _formatVersionLabel({
    required String version,
    required String buildNumber,
  }) {
    final segments = version.split('.');
    final displayVersion = segments.isNotEmpty ? segments.last : version;
    final normalizedBuildNumber = buildNumber.trim();
    if (normalizedBuildNumber.isEmpty) {
      return 'v$displayVersion';
    }
    return 'v$displayVersion (rev $normalizedBuildNumber)';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
              _buildMaintenanceSection(l10n),
            ]),
            _buildTabView([
              _buildDesktopShellSection(settings, l10n),
              if (Platform.isWindows) _buildProtocolSection(settings, l10n),
            ]),
            _buildAboutTabView(l10n),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  String _tabTitle(_SettingsTab tab, AppLocalizations l10n) {
    switch (tab) {
      case _SettingsTab.global:
        return l10n.globalSettings;
      case _SettingsTab.system:
        return l10n.systemIntegration;
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

  Widget _buildAboutTabView(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildAboutContent(l10n),
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
          subtitle: Text(l10n.appearanceTip),
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
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          _buildSwitchTile(
            title: l10n.hideTitleBar,
            subtitle: l10n.hideTitleBarTip,
            value: settings.hideTitleBar,
            onChanged: (value) => settings.setHideTitleBar(value),
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
          logSuccess: false,
          onChanged: (value) => _setRunAtStartupPreference(value, settings),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(l10n.setAsDefaultClientTip, style: fl.UIs.textGrey),
          ),
          _buildSettingsGroup([
            _buildSwitchTile(
              title: l10n.handleMagnetLinks,
              subtitle: l10n.handleMagnetLinksTip,
              value: settings.protocolMagnetEnabled,
              logSuccess: false,
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
              logSuccess: false,
              onChanged: (value) => _setProtocolPreference(
                scheme: 'thunder',
                protocolLabel: 'thunder://',
                value: value,
                persist: settings.setProtocolThunderEnabled,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  _SettingsSection _buildMaintenanceSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _SettingsSection(
      title: l10n.maintenance,
      child: _buildSettingsGroup([
        _buildTextCardTile(
          title: l10n.viewLogs,
          subtitle: Text(l10n.viewLogsTip),
          trailing: const Icon(Icons.article_outlined),
          onTap: _openLogPage,
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

  Widget _buildAboutContent(AppLocalizations l10n) {
    final repositoryUrl = Uri.parse('https://github.com/GT-610/aria2-desktop');
    final issuesUrl = Uri.parse(
      'https://github.com/GT-610/aria2-desktop/issues',
    );
    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 13),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 47, maxWidth: 47),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(kAppLogoAssetPath, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            '$kAppName\n'
            '${_versionLabel.isEmpty ? l10n.versionLoading : _versionLabel}',
            textAlign: TextAlign.center,
            style: fl.UIs.text15,
          ),
          const SizedBox(height: 13),
          SizedBox(
            height: 77,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
              scrollDirection: Axis.horizontal,
              children:
                  [
                    _buildAboutActionButton(
                      icon: Icons.code,
                      label: l10n.sourceCode,
                      onTap: () => _launchExternalUri(repositoryUrl),
                    ),
                    _buildAboutActionButton(
                      icon: Icons.feedback_outlined,
                      label: l10n.reportIssue,
                      onTap: () => _launchExternalUri(issuesUrl),
                    ),
                    _buildAboutActionButton(
                      icon: Icons.article_outlined,
                      label: l10n.license,
                      onTap: () => showLicensePage(context: context),
                    ),
                  ].map((button) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 13),
                      child: button,
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 13),
          fl.CardX(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: fl.SimpleMarkdown(
                data:
                    '''
#### ${l10n.aboutProject}
${l10n.aboutProjectDescription}

#### ${l10n.contributors}
${GithubIds.contributors.map((id) => id.markdownLink).join(' ')}

#### ${l10n.participants}
${GithubIds.participants.map((id) => id.markdownLink).join(' ')}
''',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainer,
        foregroundColor: colorScheme.primary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
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
    bool logSuccess = true,
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
                  successLog: logSuccess ? '$title changed to: $next' : null,
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

  Future<void> _setRunAtStartupPreference(bool value, Settings settings) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await settings.setAutoStart(value);
    } catch (e, stackTrace) {
      this.e(
        'Failed to save run-at-startup preference',
        error: e,
        stackTrace: stackTrace,
      );
      _showErrorSnackBar(l10n.saveSettingsFailed);
      return;
    }

    try {
      await StartupIntegrationService().setEnabled(value);
    } catch (e, stackTrace) {
      this.w(
        'Failed to apply run-at-startup preference immediately',
        error: e,
        stackTrace: stackTrace,
      );
      _showWarningSnackBar(l10n.runAtStartupRetryWarning);
    }
  }

  void _openLogPage() {
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            fl.DebugPage(args: fl.DebugPageArgs(title: l10n.viewLogs)),
      ),
    );
  }

  Future<void> _launchExternalUri(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showErrorSnackBar(AppLocalizations.of(context)!.operationFailed('$uri'));
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
      var startupPreferenceFailed = false;
      try {
        await StartupIntegrationService().reconcileStartupPreference(settings);
      } catch (e, stackTrace) {
        startupPreferenceFailed = true;
        this.w(
          'Failed to reconcile run-at-startup preference after reset',
          error: e,
          stackTrace: stackTrace,
        );
      }
      if (!mounted) {
        return;
      }

      if (failedProtocols.isNotEmpty) {
        final protocolWarning = l10n.protocolReconcileFailed(
          failedProtocols.join(', '),
        );
        _showWarningSnackBar(
          startupPreferenceFailed
              ? '$protocolWarning ${l10n.runAtStartupRetryWarning}'
              : protocolWarning,
        );
      } else if (startupPreferenceFailed) {
        _showWarningSnackBar(l10n.runAtStartupRetryWarning);
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
