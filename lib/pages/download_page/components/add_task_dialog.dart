import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../services/auto_hide_window_service.dart';
import '../../../services/protocol_integration_service.dart';
import '../../../utils/logging.dart';
import '../utils/add_task_options.dart';
import 'directory_picker.dart';

class AddTaskDialog extends StatefulWidget {
  final List<Aria2Instance> targetInstances;
  final String? defaultTargetInstanceId;
  final String? initialUri;
  final String? initialTorrentFilePath;
  final String? initialMetalinkFilePath;
  final int initialTabIndex;
  final bool initialShowDownloadsAfterAdd;
  final Future<bool> Function(
    String taskType,
    String uri,
    String downloadDir,
    String? fileContent,
    String targetInstanceId,
    Map<String, dynamic> taskOptions,
    bool showDownloadsAfterAdd,
  )
  onAddTask;

  const AddTaskDialog({
    super.key,
    required this.targetInstances,
    required this.defaultTargetInstanceId,
    this.initialUri,
    this.initialTorrentFilePath,
    this.initialMetalinkFilePath,
    this.initialTabIndex = 0,
    required this.initialShowDownloadsAfterAdd,
    required this.onAddTask,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog>
    with Loggable, SingleTickerProviderStateMixin {
  String saveLocation = '';
  final TextEditingController uriController = TextEditingController();
  final TextEditingController outputFileNameController =
      TextEditingController();
  final TextEditingController splitController = TextEditingController();
  final TextEditingController userAgentController = TextEditingController();
  final TextEditingController authorizationController = TextEditingController();
  final TextEditingController refererController = TextEditingController();
  final TextEditingController cookieController = TextEditingController();
  final TextEditingController proxyController = TextEditingController();

  late final TabController _tabController;
  bool showAdvancedOptions = false;
  bool _isSubmitting = false;
  bool _hasAttemptedClipboardAutofill = false;
  bool continueDownloads = true;
  bool autoFileRenaming = true;
  bool allowOverwrite = false;
  bool showDownloadsAfterAdd = false;
  String? selectedTorrentFilePath;
  String? selectedMetalinkFilePath;
  late String? _selectedTargetInstanceId;
  String? _lastAppliedInstanceDirectory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    )..addListener(_handleTabChanged);

    _selectedTargetInstanceId =
        widget.defaultTargetInstanceId ??
        (widget.targetInstances.isNotEmpty
            ? widget.targetInstances.first.id
            : null);
    showDownloadsAfterAdd = widget.initialShowDownloadsAfterAdd;

    if (widget.initialUri != null && widget.initialUri!.trim().isNotEmpty) {
      uriController.text = widget.initialUri!.trim();
    }
    if (widget.initialTorrentFilePath != null &&
        widget.initialTorrentFilePath!.trim().isNotEmpty) {
      selectedTorrentFilePath = widget.initialTorrentFilePath!.trim();
    }
    if (widget.initialMetalinkFilePath != null &&
        widget.initialMetalinkFilePath!.trim().isNotEmpty) {
      selectedMetalinkFilePath = widget.initialMetalinkFilePath!.trim();
    }

    if (_tabController.index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeAutofillUriFromClipboard());
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncSaveLocationFromSelectedTarget(force: true));
    });
    i('AddTaskDialog initialized');
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    uriController.dispose();
    outputFileNameController.dispose();
    splitController.dispose();
    userAgentController.dispose();
    authorizationController.dispose();
    refererController.dispose();
    cookieController.dispose();
    proxyController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted || _tabController.indexIsChanging) {
      return;
    }

    setState(() {});
    if (_tabController.index == 0) {
      unawaited(_maybeAutofillUriFromClipboard());
    }
  }

  String get _currentTaskType => switch (_tabController.index) {
    1 => 'torrent',
    2 => 'metalink',
    _ => 'uri',
  };

  Map<String, dynamic>? _buildTaskOptions(AppLocalizations l10n) {
    try {
      return buildAria2TaskOptions(
        AddTaskOptionsData(
          outputFileName: outputFileNameController.text,
          split: splitController.text,
          userAgent: userAgentController.text,
          referer: refererController.text,
          cookie: cookieController.text,
          authorization: authorizationController.text,
          allProxy: proxyController.text,
          continueDownloads: continueDownloads,
          autoFileRenaming: autoFileRenaming,
          allowOverwrite: allowOverwrite,
        ),
      );
    } on FormatException {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addTaskSplitInvalid)));
      return null;
    }
  }

  Future<void> _maybeAutofillUriFromClipboard() async {
    if (_hasAttemptedClipboardAutofill ||
        (widget.initialUri != null && widget.initialUri!.trim().isNotEmpty) ||
        uriController.text.trim().isNotEmpty) {
      return;
    }

    _hasAttemptedClipboardAutofill = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final clipboardText = data?.text?.trim();
      if (clipboardText == null || clipboardText.isEmpty) {
        return;
      }

      final normalized = _normalizeUriInput(
        clipboardText,
        showThunderWarning: false,
      );
      if (normalized == null ||
          normalized.isEmpty ||
          !mounted ||
          uriController.text.trim().isNotEmpty) {
        return;
      }

      setState(() {
        uriController.text = normalized;
      });
    } catch (e, stackTrace) {
      this.e(
        'Failed to autofill add task URI from clipboard',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  String? _normalizeUriInput(
    String rawValue, {
    required bool showThunderWarning,
  }) {
    final lines = rawValue
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return null;
    }

    final protocolService = ProtocolIntegrationService();
    final normalizedLines = <String>[];
    var hasRecognizedUri = false;
    var hasInvalidThunder = false;

    for (final line in lines) {
      final normalized = protocolService.normalizeIncomingUri(line);
      if (normalized != null) {
        normalizedLines.add(normalized);
        hasRecognizedUri = true;
        continue;
      }

      final parsed = Uri.tryParse(line);
      if (parsed != null && parsed.hasScheme) {
        if (parsed.scheme.toLowerCase() == 'thunder') {
          hasInvalidThunder = true;
          continue;
        }
        normalizedLines.add(line);
        hasRecognizedUri = true;
      }
    }

    if (hasInvalidThunder && showThunderWarning && mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.thunderLinkNormalizationFailed)),
      );
    }

    if (!hasRecognizedUri || normalizedLines.isEmpty) {
      return null;
    }

    return normalizedLines.join('\n');
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final clipboardText = data?.text;
      if (clipboardText == null || clipboardText.isEmpty) {
        return;
      }

      final normalized = _normalizeUriInput(
        clipboardText,
        showThunderWarning: true,
      );
      if (normalized == null) {
        return;
      }

      setState(() {
        uriController.text = normalized;
      });
    } catch (e, stackTrace) {
      this.e('Failed to paste', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _selectTorrentFile() async {
    try {
      final result = await AutoHideWindowService().runWithSuppressedAutoHide(
        () => FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['torrent'],
          dialogTitle: 'Select torrent file',
        ),
      );

      if (result != null) {
        setState(() {
          selectedTorrentFilePath = result.files.single.path;
        });
      }
    } catch (e, stackTrace) {
      this.e('Failed to select torrent file', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _selectMetalinkFile() async {
    try {
      final result = await AutoHideWindowService().runWithSuppressedAutoHide(
        () => FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['metalink', 'meta4'],
          dialogTitle: 'Select metalink file',
        ),
      );

      if (result != null) {
        setState(() {
          selectedMetalinkFilePath = result.files.single.path;
        });
      }
    } catch (e, stackTrace) {
      this.e(
        'Failed to select Metalink file',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _submitCurrentTab() async {
    await _submitTask(_currentTaskType);
  }

  Future<void> _syncSaveLocationFromSelectedTarget({
    required bool force,
  }) async {
    final targetInstanceId = _selectedTargetInstanceId;
    if (targetInstanceId == null) {
      return;
    }

    Aria2Instance? targetInstance;
    for (final instance in widget.targetInstances) {
      if (instance.id == targetInstanceId) {
        targetInstance = instance;
        break;
      }
    }

    if (targetInstance == null) {
      return;
    }

    _applyDefaultDirectory(targetInstance.downloadDir.trim(), force: force);
  }

  void _applyDefaultDirectory(String directory, {required bool force}) {
    if (!mounted) {
      return;
    }

    final shouldApply =
        force ||
        saveLocation.trim().isEmpty ||
        saveLocation == _lastAppliedInstanceDirectory;
    if (!shouldApply) {
      return;
    }

    setState(() {
      saveLocation = directory;
      _lastAppliedInstanceDirectory = directory;
    });
  }

  void _stepSplitCount(int delta) {
    final current = int.tryParse(splitController.text.trim()) ?? 64;
    final nextValue = (current + delta).clamp(1, 999);
    setState(() {
      splitController.text = nextValue.toString();
    });
  }

  Future<void> _submitTask(String taskType) async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSubmitting) {
      return;
    }

    final targetInstanceId = _selectedTargetInstanceId;
    if (targetInstanceId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.selectTargetInstanceFirst)));
      }
      return;
    }

    final downloadDir = saveLocation;
    final uri = uriController.text.trim();
    String? fileContent;
    final taskOptions = _buildTaskOptions(l10n);
    if (taskOptions == null) {
      return;
    }

    if (taskType == 'uri' && uri.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.enterOneOrMoreLinks)));
      }
      return;
    }

    if (taskType == 'torrent' && selectedTorrentFilePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.selectTorrentFile)));
      }
      return;
    }

    if (taskType == 'metalink' && selectedMetalinkFilePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.selectMetalinkFile)));
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (taskType == 'torrent' && selectedTorrentFilePath != null) {
        final file = File(selectedTorrentFilePath!);
        fileContent = base64Encode(await file.readAsBytes());
      } else if (taskType == 'metalink' && selectedMetalinkFilePath != null) {
        final file = File(selectedMetalinkFilePath!);
        fileContent = base64Encode(await file.readAsBytes());
      }

      final added = await widget.onAddTask(
        taskType,
        uri,
        downloadDir,
        fileContent,
        targetInstanceId,
        taskOptions,
        showDownloadsAfterAdd,
      );

      if (added && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  bool get _hasAvailableTargets => widget.targetInstances.isNotEmpty;

  Widget _buildCurrentTabContent(AppLocalizations l10n) {
    return SizedBox(
      height: 160,
      child: TabBarView(
        controller: _tabController,
        physics: _isSubmitting ? const NeverScrollableScrollPhysics() : null,
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: uriController,
                  enabled: !_isSubmitting,
                  minLines: 3,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.urlOrMagnetLink,
                    hintText: l10n.enterOneOrMoreLinks,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Btn.tile(
                    text: l10n.pasteFromClipboard,
                    icon: const Icon(Icons.paste),
                    onTap: _isSubmitting ? null : _pasteFromClipboard,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.uriSupportHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _buildFileTabContent(
            l10n: l10n,
            selectButtonText: l10n.selectTorrentFile,
            selectedFilePath: selectedTorrentFilePath,
            onSelect: _selectTorrentFile,
          ),
          _buildFileTabContent(
            l10n: l10n,
            selectButtonText: l10n.selectMetalinkFile,
            selectedFilePath: selectedMetalinkFilePath,
            onSelect: _selectMetalinkFile,
          ),
        ],
      ),
    );
  }

  Widget _buildFileTabContent({
    required AppLocalizations l10n,
    required String selectButtonText,
    required String? selectedFilePath,
    required Future<void> Function() onSelect,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.file_open, size: 56),
          const SizedBox(height: 16),
          Btn.tile(
            text: selectButtonText,
            icon: const Icon(Icons.upload_file),
            onTap: _isSubmitting ? null : onSelect,
          ),
          const SizedBox(height: 16),
          if (selectedFilePath != null)
            Text(
              l10n.selectedFile(
                selectedFilePath.split(Platform.pathSeparator).last,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildOutputAndSplitFields(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 480;
        final splitField = _buildSplitStepper(l10n);
        final outputField = Expanded(
          flex: 3,
          child: TextField(
            controller: outputFileNameController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: l10n.renameOutput,
              hintText: l10n.renameOutputPlaceholder,
            ),
          ),
        );

        if (!useTwoColumns) {
          return Column(
            children: [
              TextField(
                controller: outputFileNameController,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: l10n.renameOutput,
                  hintText: l10n.renameOutputPlaceholder,
                ),
              ),
              const SizedBox(height: 12),
              _buildSplitStepper(l10n),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [outputField, const SizedBox(width: 12), splitField],
        );
      },
    );
  }

  Widget _buildSplitStepper(AppLocalizations l10n) {
    return SizedBox(
      width: 160,
      child: TextField(
        controller: splitController,
        enabled: !_isSubmitting,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: l10n.splitCount,
          suffixIcon: SizedBox(
            width: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 20,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                    onPressed: _isSubmitting ? null : () => _stepSplitCount(1),
                    icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    splashRadius: 14,
                    onPressed: _isSubmitting ? null : () => _stepSplitCount(-1),
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProxyField(AppLocalizations l10n) {
    return TextField(
      controller: proxyController,
      enabled: !_isSubmitting,
      decoration: InputDecoration(
        labelText: l10n.perTaskProxy,
        hintText: '${l10n.exampleProxy}  ${l10n.perTaskProxyTip}',
      ),
    );
  }

  Widget _buildShowDownloadsAfterAddSwitch(AppLocalizations l10n) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: showDownloadsAfterAdd,
      onChanged: _isSubmitting
          ? null
          : (value) {
              setState(() {
                showDownloadsAfterAdd = value;
              });
            },
      title: Text(l10n.showDownloadsAfterAdd),
      subtitle: Text(l10n.addTaskShowDownloadsAfterAddTip),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }

  Widget _buildAdvancedToggle(AppLocalizations l10n) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: showAdvancedOptions,
      onChanged: _isSubmitting
          ? null
          : (value) {
              setState(() {
                showAdvancedOptions = value;
              });
            },
      title: Text(l10n.showAdvancedOptions),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    );
  }

  Widget _buildBasicActions(AppLocalizations l10n) {
    return Column(
      children: [
        _buildShowDownloadsAfterAddSwitch(l10n),
        _buildAdvancedToggle(l10n),
      ],
    );
  }

  Widget _buildAdvancedSection(AppLocalizations l10n) {
    if (!showAdvancedOptions) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: continueDownloads,
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      continueDownloads = value;
                    });
                  },
            title: Text(l10n.continueUnfinishedDownloads),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: autoFileRenaming,
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      autoFileRenaming = value;
                    });
                  },
            title: Text(l10n.autoRenameFiles),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: allowOverwrite,
            onChanged: _isSubmitting
                ? null
                : (value) {
                    setState(() {
                      allowOverwrite = value;
                    });
                  },
            title: Text(l10n.allowOverwrite),
          ),
          TextField(
            controller: userAgentController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(labelText: l10n.userAgent),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: authorizationController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(labelText: l10n.authorization),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: refererController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(labelText: l10n.referer),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cookieController,
            enabled: !_isSubmitting,
            decoration: InputDecoration(labelText: l10n.cookie),
          ),
          const SizedBox(height: 12),
          _buildProxyField(l10n),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dialogMaxHeight = (MediaQuery.sizeOf(context).height * 0.78)
        .clamp(360.0, 760.0)
        .toDouble();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          unawaited(_submitCurrentTab());
        },
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          unawaited(_submitCurrentTab());
        },
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text(l10n.addTaskDialogTitle),
          content: SizedBox(
            width: 560,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: dialogMaxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _tabController,
                    physics: _isSubmitting
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    tabs: [
                      Tab(text: l10n.uriTab),
                      Tab(text: l10n.torrentTab),
                      Tab(text: l10n.metalinkTab),
                    ],
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCurrentTabContent(l10n),
                            const Divider(height: 28),
                            if (!_hasAvailableTargets) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(l10n.noConnectedInstancesAvailable),
                              ),
                              const SizedBox(height: 12),
                            ],
                            DropdownButtonFormField<String>(
                              initialValue: _selectedTargetInstanceId,
                              decoration: InputDecoration(
                                labelText: l10n.targetInstance,
                              ),
                              items: widget.targetInstances.map((instance) {
                                final label =
                                    instance.type == InstanceType.builtin
                                    ? l10n.builtInInstance(instance.name)
                                    : instance.name;
                                return DropdownMenuItem(
                                  value: instance.id,
                                  child: Text(label),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (_isSubmitting) {
                                  return;
                                }
                                setState(() {
                                  _selectedTargetInstanceId = value;
                                });
                                unawaited(
                                  _syncSaveLocationFromSelectedTarget(
                                    force: true,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildOutputAndSplitFields(l10n),
                            const SizedBox(height: 12),
                            DirectoryPicker(
                              initialDirectory: saveLocation,
                              labelText: '',
                              onDirectoryChanged: (newLocation) {
                                if (_isSubmitting) {
                                  return;
                                }
                                setState(() {
                                  saveLocation = newLocation;
                                  _lastAppliedInstanceDirectory = null;
                                });
                              },
                              onError: (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildBasicActions(l10n),
                            _buildAdvancedSection(l10n),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Btn.cancel(
              onTap: _isSubmitting ? null : () => Navigator.of(context).pop(),
            ),
            Btn.ok(
              onTap: _hasAvailableTargets && !_isSubmitting
                  ? () => unawaited(_submitCurrentTab())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
