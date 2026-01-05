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

  /// Singleton instance
  factory BuiltinInstanceService() {
    _instance ??= BuiltinInstanceService._internal();
    return _instance!;
  }

  BuiltinInstanceService._internal() {
    initLogger();
    _initializePaths();
  }

  /// Initialize paths for built-in instance
  void _initializePaths() {
    // Get the executable path
    String executablePath = Platform.resolvedExecutable;
    Directory executableDir = Directory(executablePath).parent;

    // Use data/core directory relative to executable
    String coreDirPath = '${executableDir.path}/data/core';

    // Ensure core directory exists
    Directory coreDir = Directory(coreDirPath);
    if (!coreDir.existsSync()) {
      logger.w('Core directory does not exist: $coreDirPath, creating it...');
      coreDir.createSync(recursive: true);
    }

    // Set paths
    _aria2cPath = '$coreDirPath/aria2c.exe';
    _aria2ConfPath = '$coreDirPath/aria2.conf';
    _sessionPath = '$coreDirPath/aria2.session';
    _logPath = '$coreDirPath/aria2.log';

    logger.i('Built-in instance paths initialized:');
    logger.i('  aria2cPath: $_aria2cPath');
    logger.i('  aria2ConfPath: $_aria2ConfPath');
    logger.i('  sessionPath: $_sessionPath');
    logger.i('  logPath: $_logPath');
  }

  /// Check if the built-in Aria2 files exist
  bool checkBuiltinFiles() {
    final aria2cExists = File(_aria2cPath!).existsSync();
    final confExists = File(_aria2ConfPath!).existsSync();
    
    logger.i('Checking built-in files:');
    logger.i('  aria2c.exe exists: $aria2cExists');
    logger.i('  aria2.conf exists: $confExists');
    
    return aria2cExists && confExists;
  }

  /// Start the built-in Aria2 instance
  Future<bool> startInstance() async {
    try {
      _isConnected = false;
      
      // Check if built-in files exist
      if (!checkBuiltinFiles()) {
        logger.e('Built-in Aria2 files are missing, cannot start instance');
        return false;
      }

      // Check if process is already running
      if (_aria2Process != null) {
        logger.w('Built-in Aria2 process is already running, PID: ${_aria2Process!.pid}');
        return true;
      }

      // Build command arguments
      final List<String> args = [
        '--enable-rpc',
        '--rpc-listen-all=false',
        '--rpc-allow-origin-all',
        '--rpc-listen-port=16800',
        '--rpc-save-upload-metadata=true',
        '--rpc-max-request-size=10M',
        '--continue=true',
        '--max-concurrent-downloads=5',
        '--max-connection-per-server=16',
        '--min-split-size=10M',
        '--split=10',
        '--max-overall-download-limit=0',
        '--max-overall-upload-limit=0',
        '--max-download-limit=0',
        '--max-upload-limit=0',
        '--file-allocation=prealloc',
        '--disk-cache=64M',
        '--allow-overwrite=true',
        '--allow-piece-length-change=true',
        '--auto-file-renaming=true',
        '--check-integrity=true',
        '--remote-time=true',
        '--follow-torrent=mem',
        '--seed-time=0',
        '--bt-enable-lpd=true',
        '--bt-max-peers=100',
        '--bt-require-crypto=true',
        '--bt-save-metadata=true',
        '--bt-seed-unverified=true',
        '--listen-port=6881-6999',
        '--dht-listen-port=6881-6999',
        '--conf-path=$_aria2ConfPath',
        '--save-session=$_sessionPath',
        '--log-level=info',
        '--log=$_logPath',
      ];

      // Check if session file exists and add input-file parameter
      if (File(_sessionPath!).existsSync()) {
        args.add('--input-file=$_sessionPath');
      }

      logger.i('Starting built-in Aria2 instance with command:');
      logger.i('  $_aria2cPath ${args.join(' ')}');

      // Start the process
      _aria2Process = await Process.start(
        _aria2cPath!,
        args,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      logger.i('Built-in Aria2 instance started successfully, PID: ${_aria2Process!.pid}');

      // Monitor process exit
      _aria2Process!.exitCode.then((exitCode) {
        logger.w('Built-in Aria2 process exited with code: $exitCode');
        _aria2Process = null;
      });

      // Monitor stdout and stderr in debug mode
      if (kDebugMode) {
        _monitorProcessOutput();
      }

      return true;
    } catch (e, stackTrace) {
      logger.e('Failed to start built-in Aria2 instance', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Stop the built-in Aria2 instance
  Future<bool> stopInstance() async {
    try {
      if (_aria2Process == null) {
        logger.w('Built-in Aria2 process is not running');
        return true;
      }

      logger.i('Stopping built-in Aria2 instance, PID: ${_aria2Process!.pid}');

      await _stdoutSubscription?.cancel();
      await _stderrSubscription?.cancel();

      _aria2Process!.kill();
      await _aria2Process!.exitCode.timeout(const Duration(seconds: 5));

      logger.i('Built-in Aria2 instance stopped successfully');
      _aria2Process = null;
      _isConnected = false;
      return true;
    } catch (e, stackTrace) {
      logger.e('Failed to stop built-in Aria2 instance', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Check if the built-in instance is running
  bool isRunning() {
    return _aria2Process != null;
  }

  /// Get the PID of the running Aria2 process
  int? get pid {
    return _aria2Process?.pid;
  }

  /// Monitor process output for debugging
  void _monitorProcessOutput() {
    if (_aria2Process == null) return;

    _stdoutSubscription = _aria2Process!.stdout.transform(utf8.decoder).listen((data) {
      if (!_isConnected) {
        logger.d('Aria2 [builtin] stdout: $data');
      }
    });

    _stderrSubscription = _aria2Process!.stderr.transform(utf8.decoder).listen((data) {
      logger.e('Aria2 [builtin] stderr: $data');
    });
  }

  /// Called when connection to Aria2 is successful
  void onConnected() {
    _isConnected = true;
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    logger.i('Built-in instance connected, output monitoring stopped');
  }

  /// Get the built-in instance configuration
  Aria2Instance getBuiltinInstanceConfig() {
    return Aria2Instance(
      id: 'builtin',
      name: '内建实例',
      type: InstanceType.builtin,
      protocol: 'http',
      host: '127.0.0.1',
      port: 16800,
      secret: '',
      status: ConnectionStatus.disconnected,
    );
  }

  /// Dispose the service
  void dispose() {
    if (_aria2Process != null) {
      stopInstance();
    }
    _instance = null;
  }
}
