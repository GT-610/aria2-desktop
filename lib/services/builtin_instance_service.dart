import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/aria2_instance.dart';
import '../utils/logging.dart';

/// Service class for managing the built-in Aria2 instance
class BuiltinInstanceService with Loggable {
  static BuiltinInstanceService? _instance;
  Process? _aria2Process;
  String? _aria2cPath;
  String? _aria2ConfPath;
  String? _sessionPath;
  String? _logPath;
  bool _isConnected = false;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  factory BuiltinInstanceService() {
    _instance ??= BuiltinInstanceService._internal();
    return _instance!;
  }

  BuiltinInstanceService._internal() {
    _initializePaths();
  }

  void _initializePaths() {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = Directory(executablePath).parent;
    final coreDirPath = '${executableDir.path}/data/core';
    final coreDir = Directory(coreDirPath);

    if (!coreDir.existsSync()) {
      this.w('Core directory does not exist: $coreDirPath, creating it...');
      coreDir.createSync(recursive: true);
    }

    _aria2cPath = '$coreDirPath/aria2c.exe';
    _aria2ConfPath = '$coreDirPath/aria2.conf';
    _sessionPath = '$coreDirPath/aria2.session';
    _logPath = '$coreDirPath/aria2.log';
  }

  String _getSettingsFilePath() {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = Directory(executablePath).parent;
    final configDir = Directory('${executableDir.path}/data/config');
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }
    return '${configDir.path}/settings.json';
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

  int _getConfiguredRpcPort() {
    final settings = _readSettingsSnapshot();
    return settings['rpcListenPort'] is int
        ? settings['rpcListenPort'] as int
        : 16800;
  }

  String _getConfiguredRpcSecret() {
    final settings = _readSettingsSnapshot();
    return settings['rpcSecret'] as String? ?? '';
  }

  String _defaultSessionPath() {
    return _sessionPath!;
  }

  String _defaultLogPath() {
    return _logPath!;
  }

  String _defaultDownloadDir() {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = Directory(executablePath).parent;
    return '${executableDir.path}/data/downloads';
  }

  String _resolveConfiguredFilePath(dynamic rawValue, String fallbackPath) {
    final configuredPath = (rawValue as String? ?? '').trim();
    return configuredPath.isNotEmpty ? configuredPath : fallbackPath;
  }

  void _ensureParentDirectoryExists(String filePath) {
    final directory = File(filePath).parent;
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }

  String _formatSpeedLimitArg(dynamic rawValue) {
    final value = rawValue is num
        ? rawValue.toInt()
        : int.tryParse(rawValue?.toString() ?? '') ?? 0;
    return value > 0 ? '${value}K' : '0';
  }

  int _effectiveSeedTime(bool keepSeeding, dynamic rawValue) {
    if (keepSeeding) {
      return 525600;
    }

    return rawValue is num
        ? rawValue.toInt()
        : int.tryParse(rawValue?.toString() ?? '') ?? 60;
  }

  double _effectiveSeedRatio(bool keepSeeding, dynamic rawValue) {
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

  bool checkBuiltinFiles() {
    return validateBuiltinFiles() == null;
  }

  List<String> _buildArgs() {
    final settings = _readSettingsSnapshot();
    final rpcPort = _getConfiguredRpcPort();
    final rpcSecret = _getConfiguredRpcSecret();
    final keepSeeding = settings['keepSeeding'] == true;
    final seedTime = _effectiveSeedTime(keepSeeding, settings['seedTime']);
    final seedRatio = _effectiveSeedRatio(keepSeeding, settings['seedRatio']);
    final btListenPort =
        (settings['btListenPort'] as String? ?? '').trim().isNotEmpty
        ? (settings['btListenPort'] as String).trim()
        : '6881-6999';
    final sessionPath = _resolveConfiguredFilePath(
      settings['sessionPath'],
      _defaultSessionPath(),
    );
    final logPath = _resolveConfiguredFilePath(
      settings['logPath'],
      _defaultLogPath(),
    );
    final downloadDir = _resolveConfiguredFilePath(
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
      '--max-overall-download-limit=${_formatSpeedLimitArg(settings['maxOverallDownloadLimit'])}',
      '--max-overall-upload-limit=${_formatSpeedLimitArg(settings['maxOverallUploadLimit'])}',
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
      '--dht-listen-port=${settings['dhtListenPort'] ?? 26701}',
      '--enable-dht6=${settings['enableDht6'] ?? true}',
      '--conf-path=$_aria2ConfPath',
      '--save-session=$sessionPath',
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

  Future<bool> startInstance() async {
    try {
      _isConnected = false;

      final validationError = validateBuiltinFiles();
      if (validationError != null) {
        this.e(
          'Built-in Aria2 files are not ready, cannot start instance: '
          '$validationError',
        );
        return false;
      }

      if (_aria2Process != null) {
        this.w(
          'Built-in Aria2 process is already running, PID: ${_aria2Process!.pid}',
        );
        return true;
      }

      final args = _buildArgs();
      _aria2Process = await Process.start(
        _aria2cPath!,
        args,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      _aria2Process!.exitCode.then((exitCode) {
        this.w('Built-in Aria2 process exited with code: $exitCode');
        _aria2Process = null;
        _isConnected = false;
      });

      if (kDebugMode) {
        _monitorProcessOutput();
      }

      return true;
    } catch (e, stackTrace) {
      this.e(
        'Failed to start built-in Aria2 instance',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> stopInstance() async {
    try {
      if (_aria2Process == null) {
        this.w('Built-in Aria2 process is not running');
        return true;
      }

      await _stdoutSubscription?.cancel();
      await _stderrSubscription?.cancel();

      _aria2Process!.kill();
      await _aria2Process!.exitCode.timeout(const Duration(seconds: 5));

      _aria2Process = null;
      _isConnected = false;
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
    return _aria2Process != null;
  }

  int? get pid => _aria2Process?.pid;

  void _monitorProcessOutput() {
    if (_aria2Process == null) return;

    _stdoutSubscription = _aria2Process!.stdout.transform(utf8.decoder).listen((
      data,
    ) {
      if (!_isConnected) {
        d('Aria2 [builtin] stdout: $data');
      }
    });

    _stderrSubscription = _aria2Process!.stderr.transform(utf8.decoder).listen((
      data,
    ) {
      if (!_isConnected) {
        this.e('Aria2 [builtin] stderr: $data');
      }
    });
  }

  void onConnected() {
    _isConnected = true;
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
  }

  Aria2Instance getBuiltinInstanceConfig() {
    final settings = _readSettingsSnapshot();
    return Aria2Instance(
      id: 'builtin',
      name: 'Built-in Instance',
      type: InstanceType.builtin,
      protocol: 'ws',
      host: '127.0.0.1',
      port: _getConfiguredRpcPort(),
      secret: _getConfiguredRpcSecret(),
      downloadDir: _resolveConfiguredFilePath(
        settings['downloadDir'],
        _defaultDownloadDir(),
      ),
      status: ConnectionStatus.disconnected,
    );
  }

  void dispose() {
    if (_aria2Process != null) {
      stopInstance();
    }
    _instance = null;
  }
}
