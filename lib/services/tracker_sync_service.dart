import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/aria2_instance.dart';
import '../models/settings.dart';
import '../utils/logging.dart';
import 'aria2_rpc_client.dart';

class TrackerSourceOption {
  final String label;
  final String url;

  const TrackerSourceOption({required this.label, required this.url});
}

class TrackerSyncService with Loggable {
  static const int _maxBtTrackerLength = 6144;
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _autoSyncInterval = Duration(days: 1);

  static const List<TrackerSourceOption> sourceOptions = [
    TrackerSourceOption(
      label: 'ngosang/trackerslist - best_ip',
      url:
          'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt',
    ),
    TrackerSourceOption(
      label: 'ngosang/trackerslist - best',
      url:
          'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_best.txt',
    ),
    TrackerSourceOption(
      label: 'ngosang/trackerslist - all_ip',
      url:
          'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_all_ip.txt',
    ),
    TrackerSourceOption(
      label: 'ngosang/trackerslist - all',
      url:
          'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_all.txt',
    ),
    TrackerSourceOption(
      label: 'XIU2/TrackersListCollection - best',
      url:
          'https://fastly.jsdelivr.net/gh/XIU2/TrackersListCollection/best.txt',
    ),
    TrackerSourceOption(
      label: 'XIU2/TrackersListCollection - all',
      url: 'https://fastly.jsdelivr.net/gh/XIU2/TrackersListCollection/all.txt',
    ),
  ];

  Future<String> fetchTrackerList(String sourceUrl) async {
    final response = await http
        .get(Uri.parse(sourceUrl))
        .timeout(_requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final trackers = <String>{};
    for (final line in response.body.split(RegExp(r'\r?\n'))) {
      final tracker = line.trim();
      if (tracker.isNotEmpty) {
        trackers.add(tracker);
      }
    }

    return reduceTrackerString(trackers.join(','));
  }

  Future<bool> syncBuiltinTrackers(Settings settings) async {
    final tracker = await fetchTrackerList(settings.trackerSource);
    await settings.setBtTracker(tracker);
    await settings.setLastSyncTrackerTime(
      DateTime.now().millisecondsSinceEpoch,
    );
    return true;
  }

  /// Pushes the synced tracker list to the built-in instance. When
  /// [rpcClient] is provided it is reused and must be closed by its owner;
  /// otherwise a dedicated client is created and closed here.
  Future<bool> syncBuiltinTrackersIfNeeded(
    Settings settings, {
    Aria2Instance? builtinInstance,
    Aria2RpcClient? rpcClient,
  }) async {
    if (!settings.autoSyncTracker) {
      return false;
    }

    final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(
      settings.lastSyncTrackerTime,
    );
    final now = DateTime.now();
    final shouldSync =
        settings.lastSyncTrackerTime == 0 ||
        now.difference(lastSyncTime) >= _autoSyncInterval;

    if (!shouldSync) {
      return false;
    }

    final synced = await syncBuiltinTrackers(settings);
    if (!synced || builtinInstance == null) {
      return synced;
    }

    if (builtinInstance.status != ConnectionStatus.connected) {
      return synced;
    }

    final ownedClient = rpcClient == null;
    final client = rpcClient ?? Aria2RpcClient(builtinInstance);
    try {
      await client.setGlobalOption({'bt-tracker': settings.btTracker});
      return true;
    } finally {
      if (ownedClient) {
        await client.close();
      }
    }
  }

  @visibleForTesting
  String reduceTrackerString(String trackers) {
    if (trackers.length <= _maxBtTrackerLength) {
      return trackers;
    }

    final truncated = trackers.substring(0, _maxBtTrackerLength);
    final lastCommaIndex = truncated.lastIndexOf(',');
    if (lastCommaIndex == -1) {
      return truncated;
    }

    return truncated.substring(0, lastCommaIndex);
  }
}
