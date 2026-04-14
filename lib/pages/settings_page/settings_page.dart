import 'dart:io';

import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../generated/l10n/l10n.dart';
import '../../models/settings.dart';
import '../../services/protocol_integration_service.dart';
import './components/appearance_dialog.dart';
import '../../utils/logging.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with Loggable {
  String _version = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    try {
      i('Loading settings in settings page');
      await Provider.of<Settings>(context, listen: false).loadSettings();
      i('Settings loaded successfully');
    } catch (err) {
      this.e('Failed to load settings', error: err);
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        _showErrorSnackBar(l10n.loadSettingsFailed);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showProtocolSettings = Platform.isWindows;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Global settings section
            Text(
              l10n.globalSettings,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 1,
              shadowColor: colorScheme.shadow,
              surfaceTintColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.runAtStartup,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.runAtStartupTip),
                      value: settings.autoStart,
                      onChanged: (value) async {
                        try {
                          await settings.setAutoStart(value);
                          this.i('Auto-start setting changed to: $value');
                        } catch (e) {
                          this.e('Failed to save auto-start setting', error: e);
                          _showErrorSnackBar(l10n.saveSettingsFailed);
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        l10n.runMode,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        _runModeDescription(settings.runMode, l10n),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
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

                            try {
                              await settings.setRunMode(selection.first);
                              i(
                                'Run mode setting changed to: ${selection.first.name}',
                              );
                            } catch (e) {
                              this.e(
                                'Failed to save run mode setting',
                                error: e,
                              );
                              _showErrorSnackBar(l10n.saveSettingsFailed);
                            }
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.autoHideWindow,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.autoHideWindowTip),
                      value: settings.autoHideWindow,
                      onChanged: settings.runMode == AppRunMode.hideTray
                          ? null
                          : (value) async {
                              try {
                                await settings.setAutoHideWindow(value);
                                this.i(
                                  'Auto hide window setting changed to: $value',
                                );
                              } catch (e) {
                                this.e(
                                  'Failed to save auto hide window setting',
                                  error: e,
                                );
                                _showErrorSnackBar(l10n.saveSettingsFailed);
                              }
                            },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.showTraySpeed,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.showTraySpeedTip),
                      value: settings.showTraySpeed,
                      onChanged: settings.runMode == AppRunMode.hideTray
                          ? null
                          : (value) async {
                              try {
                                await settings.setShowTraySpeed(value);
                                this.i(
                                  'Show tray speed setting changed to: $value',
                                );
                              } catch (e) {
                                this.e(
                                  'Failed to save show tray speed setting',
                                  error: e,
                                );
                                _showErrorSnackBar(l10n.saveSettingsFailed);
                              }
                            },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.taskNotification,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.taskNotificationTip),
                      value: settings.taskNotification,
                      onChanged: (value) async {
                        try {
                          await settings.setTaskNotification(value);
                          this.i(
                            'Task notification setting changed to: $value',
                          );
                        } catch (e) {
                          this.e(
                            'Failed to save task notification setting',
                            error: e,
                          );
                          _showErrorSnackBar(l10n.saveSettingsFailed);
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.skipDeleteConfirm,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.skipDeleteConfirmTip),
                      value: settings.skipDeleteConfirm,
                      onChanged: (value) async {
                        try {
                          await settings.setSkipDeleteConfirm(value);
                          this.i(
                            'Skip delete confirm setting changed to: $value',
                          );
                        } catch (e) {
                          this.e(
                            'Failed to save skip delete confirm setting',
                            error: e,
                          );
                          _showErrorSnackBar(l10n.saveSettingsFailed);
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.resumeAllOnLaunch,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.resumeAllOnLaunchTip),
                      value: settings.resumeAllOnLaunch,
                      onChanged: (value) async {
                        try {
                          await settings.setResumeAllOnLaunch(value);
                          this.i(
                            'Resume all on launch setting changed to: $value',
                          );
                        } catch (e) {
                          this.e(
                            'Failed to save resume all on launch setting',
                            error: e,
                          );
                          _showErrorSnackBar(l10n.saveSettingsFailed);
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.showDownloadsAfterAdd,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.showDownloadsAfterAddTip),
                      value: settings.showDownloadsAfterAdd,
                      onChanged: (value) async {
                        try {
                          await settings.setShowDownloadsAfterAdd(value);
                          this.i(
                            'Show downloads after add setting changed to: $value',
                          );
                        } catch (e) {
                          this.e(
                            'Failed to save show downloads after add setting',
                            error: e,
                          );
                          _showErrorSnackBar(l10n.saveSettingsFailed);
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.showProgressBar,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.showProgressBarTip),
                      value: settings.showProgressBar,
                      onChanged: (value) async {
                        try {
                          await settings.setShowProgressBar(value);
                          this.i(
                            'Show progress bar setting changed to: $value',
                          );
                        } catch (e) {
                          this.e(
                            'Failed to save show progress bar setting',
                            error: e,
                          );
                          _showErrorSnackBar(l10n.saveSettingsFailed);
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        l10n.appearance,
                        style: theme.textTheme.bodyLarge,
                      ),
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
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: () => _showAppearanceDialog(context, settings),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        l10n.language,
                        style: theme.textTheme.bodyLarge,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_getLanguageName(settings.locale, l10n)),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: () => _showLanguageDialog(context, settings, l10n),
                    ),
                  ],
                ),
              ),
            ),

            if (showProtocolSettings) ...[
              Text(
                l10n.systemIntegration,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Card(
                margin: const EdgeInsets.only(top: 12, bottom: 24),
                elevation: 1,
                shadowColor: colorScheme.shadow,
                surfaceTintColor: colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          l10n.setAsDefaultClient,
                          style: theme.textTheme.bodyLarge,
                        ),
                        subtitle: Text(l10n.setAsDefaultClientTip),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        title: Text(
                          l10n.handleMagnetLinks,
                          style: theme.textTheme.bodyLarge,
                        ),
                        subtitle: Text(l10n.handleMagnetLinksTip),
                        value: settings.protocolMagnetEnabled,
                        onChanged: (value) => _setProtocolPreference(
                          scheme: 'magnet',
                          protocolLabel: 'magnet://',
                          value: value,
                          persist: settings.setProtocolMagnetEnabled,
                        ),
                        activeThumbColor: Colors.white,
                        activeTrackColor: colorScheme.primary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile.adaptive(
                        title: Text(
                          l10n.handleThunderLinks,
                          style: theme.textTheme.bodyLarge,
                        ),
                        subtitle: Text(l10n.handleThunderLinksTip),
                        value: settings.protocolThunderEnabled,
                        onChanged: (value) => _setProtocolPreference(
                          scheme: 'thunder',
                          protocolLabel: 'thunder://',
                          value: value,
                          persist: settings.setProtocolThunderEnabled,
                        ),
                        activeThumbColor: Colors.white,
                        activeTrackColor: colorScheme.primary,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            Text(
              l10n.maintenance,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 1,
              shadowColor: colorScheme.shadow,
              surfaceTintColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        l10n.viewLogFiles,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.viewLogFilesTip),
                      trailing: const Icon(Icons.folder_open),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: _openLogDirectory,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        l10n.resetAppSettings,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                      subtitle: Text(l10n.resetAppSettingsTip),
                      trailing: Icon(
                        Icons.restart_alt,
                        color: colorScheme.error,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: _confirmResetSettings,
                    ),
                  ],
                ),
              ),
            ),

            // Log settings section
            Text(
              l10n.logSettings,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 1,
              shadowColor: colorScheme.shadow,
              surfaceTintColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        l10n.logLevel,
                        style: theme.textTheme.bodyLarge,
                      ),
                      trailing: SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'debug',
                            label: Text(l10n.debug),
                          ),
                          ButtonSegment(value: 'info', label: Text(l10n.info)),
                          ButtonSegment(
                            value: 'warning',
                            label: Text(l10n.warning),
                          ),
                          ButtonSegment(
                            value: 'error',
                            label: Text(l10n.error),
                          ),
                        ],
                        selected: {settings.logLevelString},
                        onSelectionChanged: (newSelection) async {
                          if (newSelection.isNotEmpty) {
                            final value = newSelection.first;
                            try {
                              final logLevel = AppLogLevel.values.firstWhere(
                                (e) => e.name == value,
                              );
                              await settings.setAppLogLevel(logLevel);
                              this.i('Log level changed to: $value');
                            } catch (e) {
                              this.e(
                                'Failed to save log level setting',
                                error: e,
                              );
                              _showErrorSnackBar(l10n.saveSettingsFailed);
                            }
                          }
                        },
                        style: SegmentedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.saveLogToFile,
                        style: theme.textTheme.bodyLarge,
                      ),
                      value: settings.saveLogsToFile,
                      onChanged: (value) async {
                        try {
                          await settings.setSaveLogsToFile(value);
                          this.i(
                            'Save logs to file setting changed to: $value',
                          );
                        } catch (e) {
                          this.e('Failed to save save logs setting', error: e);
                          _showErrorSnackBar(l10n.saveSettingsFailed);
                        }
                      },
                      activeThumbColor: Colors.white,
                      activeTrackColor: colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        onPressed: _openLogDirectory,
                        icon: const Icon(Icons.file_open),
                        label: Text(l10n.viewLogFiles),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // About section
            Text(
              l10n.about,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Card(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              elevation: 1,
              shadowColor: colorScheme.shadow,
              surfaceTintColor: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        l10n.version,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        _version.isEmpty ? l10n.versionLoading : _version,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        l10n.contributors,
                        style: theme.textTheme.bodyLarge,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: Text(
                        l10n.license,
                        style: theme.textTheme.bodyLarge,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show appearance settings dialog
  void _showAppearanceDialog(BuildContext context, Settings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return AppearanceDialog(settings: settings);
      },
    );
  }

  // Get language display name
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

  // Show language selection dialog
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
      this.i('Opening log directory: ${logDirectory.path}');
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

  // Show error message
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

  // Show information message
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
