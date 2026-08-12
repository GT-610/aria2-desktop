import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/aria2_instance.dart';
import '../utils/app_data_dir.dart';
import '../utils/app_paths.dart';
import '../utils/atomic_file.dart';
import '../utils/default_download_directory.dart';
import '../utils/logging.dart';
import 'aria2_rpc_client.dart';
import 'builtin_upnp_service.dart';
import 'process_lifecycle_service.dart';

enum BuiltinInstanceApplyMode { none, liveApply, restartRequired }

/// Service class for managing the built-in Aria2 instance
class BuiltinInstanceService with Loggable {
  static const Duration _rpcShutdownTimeout = Duration(seconds: 5);

  static BuiltinInstanceService? _instance;
  Process? _aria2Process;
  String? _aria2cPath;
  String? _aria2ConfPath;
  String? _sessionPath;
  String? _logPath;
  File? _pidFile;
  int? _managedPid;
  bool _isConnected = false;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  final BuiltinUpnpService _upnpService = BuiltinUpnpService();
  BuiltinInstanceApplyMode _pendingApplyMode = BuiltinInstanceApplyMode.none;
  Future<void> _lifecycleTail = Future<void>.value();
  String? _lastStartError;

  factory BuiltinInstanceService() {
    _instance ??= BuiltinInstanceService._internal();
    return _instance!;
  }

  BuiltinInstanceService._internal() {
    _initializePaths();
  }

  void _initializePaths() {
    final paths = AppPaths.instance;
    final coreDirPath = paths.coreDirectory.path;
    final coreDir = Directory(coreDirPath);

    if (!coreDir.existsSync()) {
      w('Core directory does not exist: $coreDirPath, creating it...');
      coreDir.createSync(recursive: true);
    }

    _aria2cPath = p.join(
      paths.bundledCoreDirectory.path,
      'aria2c${Platform.isWindows ? '.exe' : ''}',
    );
    _aria2ConfPath = p.join(coreDirPath, 'aria2.conf');
    _sessionPath = p.join(coreDirPath, 'aria2.session');
    _logPath = p.join(paths.logDirectory.path, 'aria2.log');
    _pidFile = File(p.join(coreDirPath, 'aria2.pid'));
  }

  String _getSettingsFilePath() {
    final dataDir = getAppDataDirectory();
    final configDir = Directory(p.join(dataDir.path, 'config'));
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }
    return p.join(configDir.path, 'settings.json');
  }

  Map<String, dynamic> _readSettingsSnapshot() {
    try {
      final file = File(_getSettingsFilePath());
      if (!file.existsSync()) {
        return {};
      }
      final content = file.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e, stackTrace) {
      this.e(
        'Failed to read built-in settings snapshot',
        error: e,
        stackTrace: stackTrace,
      );
    }
    return {};
  }

  int _getConfiguredRpcPort([Map<String, dynamic>? settings]) {
    final s = settings ?? _readSettingsSnapshot();
    return s['rpcListenPort'] is int ? s['rpcListenPort'] as int : 16800;
  }

  String _getConfiguredRpcSecret([Map<String, dynamic>? settings]) {
    final s = settings ?? _readSettingsSnapshot();
    return s['rpcSecret'] as String? ?? '';
  }

  String _defaultSessionPath() {
    return _sessionPath!;
  }

  String _defaultLogPath() {
    return _logPath!;
  }

  String _defaultDownloadDir() {
    return getDefaultDownloadDirectorySync();
  }

  @visibleForTesting
  String resolveEffectiveBtListenPort(Map<String, dynamic> settings) {
    final raw = settings['btListenPort'];
    final configuredPort = (raw is String ? raw : '').trim();
    return configuredPort.isNotEmpty ? configuredPort : '6881-6999';
  }

  @visibleForTesting
  int resolveEffectiveDhtListenPort(Map<String, dynamic> settings) {
    final rawValue = settings['dhtListenPort'];
    if (rawValue is int && rawValue >= 1 && rawValue <= 65535) {
      return rawValue;
    }
    if (rawValue is String) {
      final parsed = int.tryParse(rawValue.trim());
      if (parsed != null && parsed >= 1 && parsed <= 65535) {
        return parsed;
      }
    }
    return 26701;
  }

  String _resolveEffectiveSessionPath(Map<String, dynamic> settings) {
    return resolveConfiguredFilePath(
      settings['sessionPath'],
      _defaultSessionPath(),
    );
  }

  @visibleForTesting
  String resolveConfiguredFilePath(dynamic rawValue, String fallbackPath) {
    final configuredPath = (rawValue is String ? rawValue : '').trim();
    return configuredPath.isNotEmpty ? configuredPath : fallbackPath;
  }

  void _ensureParentDirectoryExists(String filePath) {
    final directory = File(filePath).parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }

  @visibleForTesting
  String formatSpeedLimitArg(dynamic rawValue) {
    final value = rawValue is num
        ? rawValue.toInt()
        : int.tryParse(rawValue?.toString() ?? '') ?? 0;
    return value > 0 ? '${value}K' : '0';
  }

  @visibleForTesting
  int effectiveSeedTime(bool keepSeeding, dynamic rawValue) {
    if (keepSeeding) {
      return 525600;
    }

    return rawValue is num
        ? rawValue.toInt()
        : int.tryParse(rawValue?.toString() ?? '') ?? 60;
  }

  @visibleForTesting
  double effectiveSeedRatio(bool keepSeeding, dynamic rawValue) {
    if (keepSeeding) {
      return 0.0;
    }

    return rawValue is num
        ? rawValue.toDouble()
        : double.tryParse(rawValue?.toString() ?? '') ?? 1.0;
  }

  String? validateBuiltinFiles() {
    final requiredFiles = <({String label, String path})>[
      (label: 'aria2c', path: _aria2cPath!),
      (label: 'aria2.conf', path: _aria2ConfPath!),
    ];

    for (final fileInfo in requiredFiles) {
      final file = File(fileInfo.path);
      if (!file.existsSync()) {
        if (fileInfo.label == 'aria2c' && !Platform.isWindows) {
          return 'Built-in aria2 is not bundled for this platform. Remote instances remain available.';
        }
        return 'Missing ${fileInfo.label}: ${fileInfo.path}';
      }

      RandomAccessFile? handle;
      try {
        handle = file.openSync(mode: FileMode.read);
      } catch (e) {
        return 'Cannot open ${fileInfo.label}: ${fileInfo.path} ($e)';
      } finally {
        handle?.closeSync();
      }
    }

    return null;
  }

  String getEffectiveSessionPath() {
    final settings = _readSettingsSnapshot();
    return _resolveEffectiveSessionPath(settings);
  }

  BuiltinInstanceApplyMode get pendingApplyMode => _pendingApplyMode;
  String? get lastStartError => _lastStartError;

  void markPendingApply(BuiltinInstanceApplyMode mode) {
    if (_pendingApplyMode == BuiltinInstanceApplyMode.restartRequired &&
        mode != BuiltinInstanceApplyMode.restartRequired) {
      return;
    }
    if (_pendingApplyMode == BuiltinInstanceApplyMode.liveApply &&
        mode == BuiltinInstanceApplyMode.none) {
      return;
    }
    _pendingApplyMode = mode;
  }

  void clearPendingApply({BuiltinInstanceApplyMode? appliedMode}) {
    if (appliedMode == null ||
        appliedMode == BuiltinInstanceApplyMode.restartRequired) {
      _pendingApplyMode = BuiltinInstanceApplyMode.none;
      return;
    }

    if (appliedMode == BuiltinInstanceApplyMode.liveApply &&
        _pendingApplyMode == BuiltinInstanceApplyMode.liveApply) {
      _pendingApplyMode = BuiltinInstanceApplyMode.none;
    }
  }

  Future<bool> resetSessionFile() async {
    final sessionPath = getEffectiveSessionPath();

    if (isRunning()) {
      final stopped = await stopInstance();
      if (!stopped) {
        throw Exception('Failed to stop the built-in instance before reset');
      }
    }

    final file = File(sessionPath);
    if (!file.existsSync()) {
      return false;
    }

    try {
      await file.delete();
      return true;
    } catch (e, stackTrace) {
      this.e(
        'Failed to reset built-in session file',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> syncUpnpStateForRunningInstance() async {
    if (!isRunning()) {
      return;
    }

    final settings = _readSettingsSnapshot();
    await _upnpService.syncMappings(
      enabled: settings['enableUpnp'] == true,
      btListenPort: resolveEffectiveBtListenPort(settings),
      dhtListenPort: resolveEffectiveDhtListenPort(settings),
    );
  }

  List<String> _buildArgs() {
    final settings = _readSettingsSnapshot();
    final rpcPort = _getConfiguredRpcPort(settings);
    final rpcSecret = _getConfiguredRpcSecret(settings);
    final keepSeeding = settings['keepSeeding'] == true;
    final seedTime = effectiveSeedTime(keepSeeding, settings['seedTime']);
    final seedRatio = effectiveSeedRatio(keepSeeding, settings['seedRatio']);
    final btListenPort = resolveEffectiveBtListenPort(settings);
    final sessionPath = _resolveEffectiveSessionPath(settings);
    final logPath = resolveConfiguredFilePath(
      settings['logPath'],
      _defaultLogPath(),
    );
    final downloadDir = resolveConfiguredFilePath(
      settings['downloadDir'],
      _defaultDownloadDir(),
    );

    _ensureParentDirectoryExists(sessionPath);
    _ensureParentDirectoryExists(logPath);
    Directory(downloadDir).createSync(recursive: true);

    final args = <String>[
      '--enable-rpc',
      '--rpc-listen-all=false',
      '--rpc-allow-origin-all',
      '--rpc-listen-port=$rpcPort',
      '--rpc-save-upload-metadata=true',
      '--rpc-max-request-size=10M',
      '--continue=${settings['continueDownloads'] ?? true}',
      '--max-concurrent-downloads=${settings['maxConcurrentDownloads'] ?? 5}',
      '--max-connection-per-server=${settings['maxConnectionPerServer'] ?? 16}',
      '--min-split-size=10M',
      '--split=${settings['split'] ?? 16}',
      '--max-overall-download-limit=${formatSpeedLimitArg(settings['maxOverallDownloadLimit'])}',
      '--max-overall-upload-limit=${formatSpeedLimitArg(settings['maxOverallUploadLimit'])}',
      '--max-download-limit=0',
      '--max-upload-limit=0',
      '--file-allocation=prealloc',
      '--disk-cache=64M',
      '--dir=$downloadDir',
      '--allow-overwrite=${settings['allowOverwrite'] ?? false}',
      '--allow-piece-length-change=true',
      '--auto-file-renaming=${settings['autoFileRenaming'] ?? true}',
      '--check-integrity=true',
      '--remote-time=true',
      '--follow-torrent=mem',
      '--seed-time=$seedTime',
      '--seed-ratio=$seedRatio',
      '--bt-enable-lpd=true',
      '--bt-max-peers=100',
      '--bt-require-crypto=${settings['btForceEncryption'] ?? false}',
      '--bt-save-metadata=${settings['btSaveMetadata'] ?? true}',
      '--bt-load-saved-metadata=${settings['btLoadSavedMetadata'] ?? true}',
      '--bt-seed-unverified=${settings['keepSeeding'] ?? false}',
      '--listen-port=$btListenPort',
      '--dht-listen-port=${resolveEffectiveDhtListenPort(settings)}',
      '--enable-dht6=${settings['enableDht6'] ?? true}',
      '--conf-path=$_aria2ConfPath',
      '--save-session=$sessionPath',
      '--save-session-interval=30',
      '--force-save=false',
      '--log-level=info',
      '--log=$logPath',
    ];

    final allProxy = settings['allProxy'] as String? ?? '';
    final noProxy = settings['noProxy'] as String? ?? '';
    final proxyEnabled = settings['proxyEnabled'] == true;
    final userAgent = settings['userAgent'] as String? ?? '';
    final btTracker = settings['btTracker'] as String? ?? '';
    final btExcludeTracker = settings['btExcludeTracker'] as String? ?? '';

    if (rpcSecret.isNotEmpty) {
      args.add('--rpc-secret=$rpcSecret');
    }
    if (proxyEnabled && allProxy.isNotEmpty) {
      args.add('--all-proxy=$allProxy');
    }
    if (proxyEnabled && noProxy.isNotEmpty) {
      args.add('--no-proxy=$noProxy');
    }
    if (userAgent.isNotEmpty) {
      args.add('--user-agent=$userAgent');
    }
    if (btTracker.isNotEmpty) {
      args.add('--bt-tracker=$btTracker');
    }
    if (btExcludeTracker.isNotEmpty) {
      args.add('--bt-exclude-tracker=$btExcludeTracker');
    }
    if (File(sessionPath).existsSync()) {
      args.add('--input-file=$sessionPath');
    }

    return args;
  }

  Future<T> _serializeLifecycle<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lifecycleTail = _lifecycleTail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<bool> startInstance() => _serializeLifecycle(_startInstance);

  Future<bool> _startInstance() async {
    try {
      _isConnected = false;
      _lastStartError = null;

      final validationError = validateBuiltinFiles();
      if (validationError != null) {
        _lastStartError = validationError;
        e(
          'Built-in Aria2 files are not ready, cannot start instance: '
          '$validationError',
        );
        return false;
      }

      if (!await ProcessLifecycleService.instance.canManageBuiltinProcess()) {
        _lastStartError =
            'Another Setsuna window is already managing the built-in aria2 instance';
        e(
          'Another Setsuna process owns the built-in aria2 lifecycle lock; '
          'refusing to start a duplicate process',
        );
        return false;
      }

      if (_aria2Process != null) {
        w(
          'Built-in Aria2 process is already running, PID: ${_aria2Process!.pid}',
        );
        unawaited(syncUpnpStateForRunningInstance());
        return true;
      }

      if (await _adoptPersistedProcess()) {
        i('Adopted existing built-in Aria2 process, PID: $_managedPid');
        unawaited(syncUpnpStateForRunningInstance());
        return true;
      }

      final legacyPid = await ProcessLifecycleService.instance
          .findExpectedProcess(
            port: _getConfiguredRpcPort(_readSettingsSnapshot()),
            executablePath: _aria2cPath!,
          );
      if (legacyPid != null) {
        _managedPid = legacyPid;
        await _persistManagedPid(legacyPid);
        await ProcessLifecycleService.instance.attachToAppLifecycle(legacyPid);
        i('Adopted legacy built-in Aria2 process, PID: $legacyPid');
        unawaited(syncUpnpStateForRunningInstance());
        return true;
      }

      if (await _isRpcReachable()) {
        _lastStartError =
            'The built-in aria2 RPC port is already used by another process';
        e(
          'The configured built-in aria2 RPC endpoint is already in use by '
          'an unmanaged process; refusing to start a duplicate process',
        );
        return false;
      }

      final args = _buildArgs();
      final process = await Process.start(
        _aria2cPath!,
        args,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
      _aria2Process = process;
      _managedPid = process.pid;
      try {
        await _persistManagedPid(process.pid);
        if (!await ProcessLifecycleService.instance.attachToAppLifecycle(
          process.pid,
        )) {
          w(
            'Built-in Aria2 process ${process.pid} could not be attached to the '
            'application lifecycle safety net',
          );
        }
      } catch (_) {
        process.kill();
        _aria2Process = null;
        _managedPid = null;
        rethrow;
      }

      process.exitCode.then((exitCode) {
        w('Built-in Aria2 process exited with code: $exitCode');
        if (identical(_aria2Process, process)) {
          _aria2Process = null;
          _managedPid = null;
          _isConnected = false;
          unawaited(_deletePidFileIfMatches(process.pid));
          unawaited(_upnpService.shutdown());
        }
      });

      _monitorProcessOutput(process);

      unawaited(syncUpnpStateForRunningInstance());

      return true;
    } catch (e, stackTrace) {
      _lastStartError = 'Failed to start built-in aria2: $e';
      this.e(
        'Failed to start built-in Aria2 instance',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> stopInstance() => _serializeLifecycle(_stopInstance);

  Future<bool> _stopInstance() async {
    try {
      if (_aria2Process == null && !await _adoptPersistedProcess()) {
        if (await _isRpcReachable()) {
          w(
            'Built-in aria2 RPC is reachable but the process is not owned by '
            'this Setsuna process; leaving it untouched',
          );
          return false;
        }
        w('Built-in Aria2 process is not running');
        await _clearManagedProcessState();
        return true;
      }

      try {
        await _shutdownThroughRpcIfPossible().timeout(_rpcShutdownTimeout);
      } on TimeoutException {
        w(
          'Timed out waiting for built-in Aria2 RPC shutdown, terminating process',
        );
        _aria2Process?.kill();
      }

      final process = _aria2Process;
      final managedPid = _managedPid;
      if (process != null) {
        try {
          await process.exitCode.timeout(const Duration(seconds: 5));
        } on TimeoutException {
          w(
            'Built-in Aria2 did not exit after RPC shutdown, terminating process',
          );
          process.kill();
          await process.exitCode.timeout(const Duration(seconds: 5));
        }
      } else if (managedPid != null &&
          await ProcessLifecycleService.instance.isExpectedProcess(
            managedPid,
            _aria2cPath!,
          )) {
        Process.killPid(managedPid);
        await _waitForPidExit(managedPid);
      }

      await _clearManagedProcessState();
      await _cancelProcessOutput();
      await _upnpService.shutdown();
      return true;
    } catch (e, stackTrace) {
      this.e(
        'Failed to stop built-in Aria2 instance',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  bool isRunning() {
    return _aria2Process != null || _managedPid != null;
  }

  Future<bool> _adoptPersistedProcess() async {
    final pid = await _readPersistedPid();
    if (pid == null) {
      return false;
    }
    if (!await ProcessLifecycleService.instance.isExpectedProcess(
      pid,
      _aria2cPath!,
    )) {
      await _deletePidFileIfMatches(pid);
      return false;
    }
    _managedPid = pid;
    await ProcessLifecycleService.instance.attachToAppLifecycle(pid);
    return true;
  }

  Future<bool> _isRpcReachable() async {
    final client = Aria2RpcClient(
      getBuiltinInstanceConfig(),
      requestTimeout: const Duration(seconds: 1),
      retryDelay: const Duration(milliseconds: 50),
    );
    try {
      return await client.testConnection();
    } on UnauthorizedException {
      return true;
    } catch (_) {
      return false;
    } finally {
      await client.close();
    }
  }

  Future<int?> _readPersistedPid() async {
    final pidFile = _pidFile;
    if (pidFile == null || !await pidFile.exists()) {
      return null;
    }
    try {
      final pid = int.tryParse((await pidFile.readAsString()).trim());
      if (pid == null || pid <= 0) {
        await pidFile.delete();
        return null;
      }
      return pid;
    } on FileSystemException catch (error, stackTrace) {
      w(
        'Failed to read the built-in aria2 PID file',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _persistManagedPid(int pid) async {
    final pidFile = _pidFile;
    if (pidFile == null) {
      return;
    }
    await AtomicFile.writeString(pidFile, '$pid\n');
  }

  Future<void> _deletePidFileIfMatches(int pid) async {
    final pidFile = _pidFile;
    if (pidFile == null || !await pidFile.exists()) {
      return;
    }
    try {
      final persistedPid = int.tryParse((await pidFile.readAsString()).trim());
      if (persistedPid == pid) {
        await pidFile.delete();
      }
    } on FileSystemException catch (error, stackTrace) {
      w(
        'Failed to delete the built-in aria2 PID file',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _waitForPidExit(int pid) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (!await ProcessLifecycleService.instance.isExpectedProcess(
        pid,
        _aria2cPath!,
      )) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('aria2 process $pid did not exit');
  }

  Future<void> _clearManagedProcessState() async {
    final pid = _managedPid;
    _aria2Process = null;
    _managedPid = null;
    _isConnected = false;
    if (pid != null) {
      await _deletePidFileIfMatches(pid);
    }
  }

  Future<void> _shutdownThroughRpcIfPossible() async {
    final client = Aria2RpcClient(getBuiltinInstanceConfig());
    try {
      await client.saveSession().timeout(_rpcShutdownTimeout);
      await client.shutdown(force: true).timeout(_rpcShutdownTimeout);
    } on TimeoutException {
      w(
        'Timed out during built-in Aria2 RPC shutdown; falling back to process termination',
      );
      _aria2Process?.kill();
    } catch (e, stackTrace) {
      w(
        'Failed to stop built-in Aria2 through RPC; falling back to process termination',
        error: e,
        stackTrace: stackTrace,
      );
      _aria2Process?.kill();
    } finally {
      await client.close();
    }
  }

  void _monitorProcessOutput(Process process) {
    _stdoutSubscription = process.stdout.transform(utf8.decoder).listen((_) {});

    _stderrSubscription = process.stderr.transform(utf8.decoder).listen((data) {
      if (kDebugMode && !_isConnected) {
        e('Aria2 [builtin] stderr: $data');
      }
    });
  }

  Future<void> _cancelProcessOutput() async {
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
  }

  void onConnected() {
    _isConnected = true;
    _lastStartError = null;
    clearPendingApply();
  }

  Aria2Instance getBuiltinInstanceConfig() {
    final settings = _readSettingsSnapshot();
    return Aria2Instance(
      id: 'builtin',
      name: 'Built-in Instance',
      type: InstanceType.builtin,
      protocol: 'ws',
      host: '127.0.0.1',
      port: _getConfiguredRpcPort(settings),
      secret: _getConfiguredRpcSecret(settings),
      downloadDir: resolveConfiguredFilePath(
        settings['downloadDir'],
        _defaultDownloadDir(),
      ),
      status: ConnectionStatus.disconnected,
    );
  }

  void dispose() {
    if (isRunning()) {
      unawaited(stopInstance());
    }
    clearPendingApply();
    _instance = null;
  }
}
