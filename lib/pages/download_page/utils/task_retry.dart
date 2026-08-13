import 'package:path/path.dart' as p;

import '../models/download_task.dart';

class TaskRetrySource {
  const TaskRetrySource({required this.uris, this.outputName});

  final List<String> uris;
  final String? outputName;
}

List<TaskRetrySource> buildTaskRetrySources(DownloadTask task) {
  final existingMagnet = task.uris
      ?.map((uri) => uri.trim())
      .where(_hasValidBtihTopic)
      .firstOrNull;
  if (existingMagnet != null) {
    return <TaskRetrySource>[
      TaskRetrySource(uris: <String>[existingMagnet]),
    ];
  }

  final infoHash = task.infoHash?.trim() ?? '';
  if (_isValidBtih(infoHash)) {
    final queryParameters = <String, List<String>>{
      'xt': <String>['urn:btih:$infoHash'],
    };
    final name = task.name.trim();
    if (name.isNotEmpty) {
      queryParameters['dn'] = <String>[name];
    }
    final trackers = task.trackers
        ?.map((tracker) => tracker.trim())
        .where((tracker) => tracker.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (trackers != null && trackers.isNotEmpty) {
      queryParameters['tr'] = trackers;
    }

    return <TaskRetrySource>[
      TaskRetrySource(
        uris: <String>[
          Uri(scheme: 'magnet', queryParameters: queryParameters).toString(),
        ],
      ),
    ];
  }

  final sources = <TaskRetrySource>[];
  for (final file in task.files ?? const <Map<String, dynamic>>[]) {
    final rawUris = file['uris'];
    if (rawUris is! List) {
      continue;
    }
    final uris = rawUris
        .whereType<Map>()
        .map((item) => item['uri']?.toString().trim() ?? '')
        .where((uri) => uri.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (uris.isEmpty) {
      continue;
    }

    final path = file['path']?.toString().trim() ?? '';
    final outputName = _relativeOutputPath(path, task.dir);
    sources.add(TaskRetrySource(uris: uris, outputName: outputName));
  }
  if (sources.isNotEmpty) {
    return sources;
  }

  final fallbackUris = task.uris
      ?.map((uri) => uri.trim())
      .where(
        (uri) =>
            uri.isNotEmpty &&
            (!uri.toLowerCase().startsWith('magnet:') ||
                _hasValidBtihTopic(uri)),
      )
      .toSet()
      .toList(growable: false);
  if (fallbackUris == null || fallbackUris.isEmpty) {
    return const <TaskRetrySource>[];
  }
  return <TaskRetrySource>[TaskRetrySource(uris: fallbackUris)];
}

bool _hasValidBtihTopic(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme.toLowerCase() != 'magnet') {
    return false;
  }
  return uri.queryParametersAll['xt']?.any((topic) {
        const prefix = 'urn:btih:';
        return topic.toLowerCase().startsWith(prefix) &&
            _isValidBtih(topic.substring(prefix.length));
      }) ==
      true;
}

bool _isValidBtih(String value) {
  return RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(value) ||
      RegExp(r'^[A-Z2-7]{32}$', caseSensitive: false).hasMatch(value);
}

String? _relativeOutputPath(String value, String? taskDir) {
  if (value.isEmpty) {
    return null;
  }

  final usesWindowsPaths =
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value) ||
      value.contains(r'\') ||
      (taskDir?.contains(r'\') ?? false);
  final context = usesWindowsPaths ? p.windows : p.posix;
  final normalizedPath = context.normalize(value);
  final normalizedDir = taskDir?.trim().isNotEmpty == true
      ? context.normalize(taskDir!.trim())
      : null;

  if (!context.isAbsolute(normalizedPath)) {
    return context.split(normalizedPath).contains('..')
        ? context.basename(normalizedPath)
        : normalizedPath;
  }
  if (normalizedDir != null &&
      context.isWithin(normalizedDir, normalizedPath)) {
    return context.relative(normalizedPath, from: normalizedDir);
  }
  return context.basename(normalizedPath);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
