import '../models/download_task.dart';

class TaskRetrySource {
  const TaskRetrySource({required this.uris, this.outputName});

  final List<String> uris;
  final String? outputName;
}

List<TaskRetrySource> buildTaskRetrySources(DownloadTask task) {
  final existingMagnet = task.uris
      ?.map((uri) => uri.trim())
      .where((uri) => uri.toLowerCase().startsWith('magnet:?'))
      .firstOrNull;
  if (existingMagnet != null) {
    return <TaskRetrySource>[
      TaskRetrySource(uris: <String>[existingMagnet]),
    ];
  }

  final infoHash = task.infoHash?.trim() ?? '';
  if (infoHash.isNotEmpty) {
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
    final outputName = path.isEmpty
        ? null
        : path
              .split(RegExp(r'[\\/]'))
              .where((part) => part.isNotEmpty)
              .lastOrNull;
    sources.add(TaskRetrySource(uris: uris, outputName: outputName));
  }
  if (sources.isNotEmpty) {
    return sources;
  }

  final fallbackUris = task.uris
      ?.map((uri) => uri.trim())
      .where((uri) => uri.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (fallbackUris == null || fallbackUris.isEmpty) {
    return const <TaskRetrySource>[];
  }
  return <TaskRetrySource>[TaskRetrySource(uris: fallbackUris)];
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? get lastOrNull => isEmpty ? null : last;
}
