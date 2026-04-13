import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../generated/l10n/l10n.dart';
import '../../models/settings.dart';
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
                    SwitchListTile.adaptive(
                      title: Text(
                        l10n.minimizeToTray,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(l10n.minimizeToTrayTip),
                      value: settings.minimizeToTray,
                      onChanged: (value) async {
                        try {
                          await settings.setMinimizeToTray(value);
                          this.i('Minimize to tray setting changed to: $value');
                        } catch (e) {
                          this.e(
                            'Failed to save minimize to tray setting',
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
                      onChanged: (value) async {
                        try {
                          await settings.setShowTraySpeed(value);
                          this.i('Show tray speed setting changed to: $value');
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
                        onPressed: () async {
                          try {
                            this.i('Attempting to open log directory');
                            _showInfoSnackBar(
                              l10n.thisFeatureWillBeImplemented,
                            );
                          } catch (e) {
                            this.e('Failed to open log directory', error: e);
                            _showErrorSnackBar(l10n.cannotOpenLogDirectory);
                          }
                        },
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
}
