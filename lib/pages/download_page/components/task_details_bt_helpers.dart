import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../utils/format_utils.dart';
import '../models/download_task.dart';

class TaskDetailsBtHelpers {
  static final _azureusPattern = RegExp(r'^-([A-Za-z~]{2})(.{4})-');
  static final _digitPattern = RegExp(r'[0-9]');
  static final _letterPattern = RegExp(r'[A-Za-z]');

  static String buildFileSelectionSignature(List<Map<String, dynamic>> files) {
    return files
        .map(
          (file) =>
              '${file['index'] ?? ''}:${file['selected'] as String? ?? 'true'}',
        )
        .join('|');
  }

  static Widget buildBitfieldVisualization(
    BuildContext context,
    DownloadTask task,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final bitfield = task.bitfield;

    if (bitfield == null || bitfield.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              l10n.noPieceInformation,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noPieceInformationHint,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final pieces = parseHexBitfield(bitfield);
    final totalPieces = pieces.length;
    final completedPieces = pieces.where((piece) => piece == 15).length;
    final partialPieces = pieces
        .where((piece) => piece > 0 && piece < 15)
        .length;
    final missingPieces = pieces.where((piece) => piece == 0).length;
    final completionPercentage = totalPieces > 0
        ? ((completedPieces + partialPieces * 0.5) / totalPieces) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pieceStatistics,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatRow(l10n.totalPieces, '$totalPieces'),
                _buildStatRow(l10n.completed, '$completedPieces', Colors.green),
                _buildStatRow(l10n.partial, '$partialPieces', Colors.yellow),
                _buildStatRow(l10n.missing, '$missingPieces', Colors.grey),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completionPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 4),
                Text(l10n.completion(completionPercentage.toStringAsFixed(2))),
              ],
            ),
          ),
        ),
        Text(
          l10n.pieceMap,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildPiecesGrid(pieces),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.legend,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildLegendRow(Colors.green, '${l10n.completed} (f)'),
                _buildLegendRow(Colors.lightGreen, l10n.highProgress),
                _buildLegendRow(Colors.yellow, l10n.mediumProgress),
                _buildLegendRow(Colors.orange, l10n.lowProgress),
                _buildLegendRow(Colors.grey, '${l10n.missing} (0)'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget buildPeersView({
    required BuildContext context,
    required List<Map<String, dynamic>> peers,
    required bool isLoading,
    required String? error,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading && peers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && error.isNotEmpty && peers.isEmpty) {
      return Text(error);
    }

    if (peers.isEmpty) {
      return Text(l10n.noPeerInformation);
    }

    return ListView.builder(
      itemCount: peers.length,
      itemBuilder: (context, index) => _buildPeerCard(context, peers[index]),
    );
  }

  static Widget _buildPeerCard(
    BuildContext context,
    Map<String, dynamic> peer,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ip = peer['ip']?.toString() ?? '--';
    final port = peer['port']?.toString() ?? '--';
    final peerId = _parsePeerClient(peer['peerId']?.toString());
    final bitfield = peer['bitfield']?.toString();
    final pieces = bitfield == null || bitfield.isEmpty
        ? const <int>[]
        : parseHexBitfield(bitfield);
    final progress = _bitfieldToPercent(pieces);
    final isSeeder = (peer['seeder']?.toString() ?? 'false') == 'true';
    final uploadSpeed = formatBytes(
      int.tryParse(peer['uploadSpeed']?.toString() ?? '0') ?? 0,
    );
    final downloadSpeed = formatBytes(
      int.tryParse(peer['downloadSpeed']?.toString() ?? '0') ?? 0,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$ip:$port',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSeeder)
                  Tooltip(
                    message: l10n.seeding,
                    child: const Icon(
                      Icons.done_all,
                      size: 16,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${l10n.clientLabel}: $peerId',
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: PeerBitfieldBar(pieces: pieces),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${progress.toStringAsFixed(0)}%'),
                const Spacer(),
                Text(
                  '${l10n.uploadShort}: $uploadSpeed/s  '
                  '${l10n.downloadShort}: $downloadSpeed/s',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Swarm availability estimate: the union of pieces available across all
  /// peers combined with the locally completed pieces.
  static double? estimateHealthPercent(
    DownloadTask task,
    List<Map<String, dynamic>> peers,
  ) {
    final ownBitfield = task.bitfield;
    if (ownBitfield == null || ownBitfield.isEmpty) {
      return null;
    }
    final ownPieces = parseHexBitfield(ownBitfield);
    if (ownPieces.isEmpty) {
      return null;
    }

    final peerPieceMaps = <List<int>>[
      for (final peer in peers)
        parseHexBitfield(peer['bitfield']?.toString() ?? ''),
    ]..removeWhere((pieces) => pieces.isEmpty);

    var available = 0;
    for (var i = 0; i < ownPieces.length; i++) {
      final haveLocally = ownPieces[i] == 15;
      final availableAtAnyPeer = peerPieceMaps.any(
        (pieces) => i < pieces.length && pieces[i] > 0,
      );
      if (haveLocally || availableAtAnyPeer) {
        available++;
      }
    }

    return (available / ownPieces.length) * 100;
  }

  static TaskDetailsTorrentOverviewMetadata parseTorrentMetadata(
    String? bittorrentInfo,
  ) {
    if (bittorrentInfo == null || bittorrentInfo.trim().isEmpty) {
      return const TaskDetailsTorrentOverviewMetadata();
    }

    try {
      final decoded = json.decode(bittorrentInfo);
      if (decoded is! Map) {
        return const TaskDetailsTorrentOverviewMetadata();
      }

      final map = Map<String, dynamic>.from(decoded);
      final comment = (map['comment.utf-8'] ?? map['comment'])?.toString();
      final creationTimestamp = int.tryParse(
        map['creationDate']?.toString() ?? '',
      );

      return TaskDetailsTorrentOverviewMetadata(
        comment: comment,
        creationDate: creationTimestamp != null && creationTimestamp > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                creationTimestamp * 1000,
                isUtc: true,
              )
            : null,
      );
    } catch (_) {
      // Best-effort parsing: return empty metadata if torrent data is malformed
      return const TaskDetailsTorrentOverviewMetadata();
    }
  }

  static bool hasTorrentOverviewData(
    DownloadTask task,
    TaskDetailsTorrentOverviewMetadata metadata,
  ) {
    return (task.infoHash?.trim().isNotEmpty ?? false) ||
        (task.pieceLength != null && task.pieceLength! > 0) ||
        (task.numPieces != null && task.numPieces! > 0) ||
        metadata.creationDate != null ||
        (metadata.comment?.trim().isNotEmpty ?? false);
  }

  static Widget buildSectionDivider(BuildContext context, String label) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withValues(alpha: 0.5);
    return Row(
      children: [
        Expanded(child: Divider(color: dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: dividerColor)),
      ],
    );
  }

  static String formatShareRatio(DownloadTask task) {
    if (task.completedLengthBytes <= 0 || task.uploadLengthBytes <= 0) {
      return '0';
    }

    final ratio = task.uploadLengthBytes / task.completedLengthBytes;
    return ratio.toStringAsFixed(4);
  }

  static double _bitfieldToPercent(List<int> pieces) {
    if (pieces.isEmpty) {
      return 0;
    }
    final completed = pieces.fold<int>(0, (sum, value) => sum + value);
    return (completed / (pieces.length * 15)) * 100;
  }

  static const String _unknownPeerId =
      '%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00';

  static const Map<String, String> _azureusClientNames = {
    'AG': 'Ares',
    'AR': 'Arctic',
    'AT': 'Artemis',
    'AV': 'Avicora',
    'AX': 'BitPump',
    'AZ': 'Vuze',
    'BC': 'BitComet',
    'BE': 'BitTorrent SDK',
    'BG': 'BTGetit',
    'BR': 'BitRocket',
    'BS': 'BTSlave',
    'BT': 'Mainline',
    'BX': 'BittorrentX',
    'CD': 'Enhanced CTorrent',
    'CT': 'CTorrent',
    'DE': 'Deluge',
    'DP': 'Propagate Data Client',
    'EB': 'EBit',
    'ES': 'electric sheep',
    'FC': 'FileCroc',
    'FT': 'FoxTorrent',
    'GS': 'GSTorrent',
    'HK': 'Hekate',
    'HL': 'Halite',
    'HM': 'hMule',
    'KG': 'KGet',
    'KT': 'KTorrent',
    'LC': 'LeechCraft',
    'LH': 'LH-ABC',
    'LP': 'Lphant',
    'LT': 'libtorrent',
    'lt': 'libTorrent',
    'LW': 'LimeWire',
    'MO': 'MonoTorrent',
    'MP': 'MooPolice',
    'MR': 'Miro',
    'MT': 'MoonlightTorrent',
    'NX': 'Net Transport',
    'PD': 'Pando',
    'PT': 'PHPTracker',
    'qB': 'qBittorrent',
    'QD': 'QQDownload',
    'QT': 'Qt 4 Torrent example',
    'RT': 'Retriever',
    'S~': 'Shareaza alpha/beta',
    'SB': 'Swiftbit',
    'SS': 'SwarmScope',
    'ST': 'SymTorrent',
    'st': 'Sharktorrent',
    'SZ': 'Shareaza',
    'TN': 'TorrentDotNET',
    'TR': 'Transmission',
    'TS': 'Torrentstorm',
    'TT': 'TuoTu',
    'UL': 'uLeecher',
    'UT': 'μTorrent',
    'VG': 'Vagaa',
    'WT': 'BitLet',
    'WY': 'FireTorrent',
    'XF': 'Xfplay',
    'XL': 'Xunlei',
    'XT': 'XanTorrent',
    'XX': 'Xtorrent',
    'ZT': 'ZipTorrent',
  };

  static String _parsePeerClient(String? rawPeerId) {
    if (rawPeerId == null || rawPeerId.isEmpty || rawPeerId == _unknownPeerId) {
      return 'unknown';
    }

    final decoded = _decodePeerId(rawPeerId);
    if (decoded == null || decoded.isEmpty) {
      return 'unknown';
    }

    final azureusMatch = _azureusPattern.firstMatch(decoded);
    if (azureusMatch != null) {
      final clientCode = azureusMatch.group(1)!;
      final versionRaw = azureusMatch.group(2)!;
      final clientName = _azureusClientNames[clientCode] ?? clientCode;
      final version = _formatPeerVersion(versionRaw);
      return version.isEmpty ? clientName : '$clientName v$version';
    }

    return decoded;
  }

  static String? _decodePeerId(String rawPeerId) {
    try {
      final bytes = <int>[];
      for (var i = 0; i < rawPeerId.length;) {
        final char = rawPeerId[i];
        if (char == '%' && i + 2 < rawPeerId.length) {
          final hex = rawPeerId.substring(i + 1, i + 3);
          final value = int.tryParse(hex, radix: 16);
          if (value != null) {
            bytes.add(value);
            i += 3;
            continue;
          }
        }
        bytes.add(char.codeUnitAt(0));
        i++;
      }

      if (bytes.every((byte) => byte == 0)) {
        return null;
      }

      return latin1.decode(bytes, allowInvalid: true);
    } catch (_) {
      return null;
    }
  }

  static String _formatPeerVersion(String rawVersion) {
    final segments = <String>[];
    for (final char in rawVersion.split('')) {
      if (_digitPattern.hasMatch(char)) {
        segments.add(char);
      } else if (_letterPattern.hasMatch(char)) {
        segments.add(char.toLowerCase());
      }
    }

    while (segments.length > 1 && segments.last == '0') {
      segments.removeLast();
    }

    return segments.join('.');
  }

  static Widget _buildStatRow(String label, String value, [Color? color]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (color != null) ...[
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                color: color,
              ),
            ],
            Text(label),
          ],
        ),
        Text(value),
      ],
    );
  }

  static Widget _buildLegendRow(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 8),
          color: color,
        ),
        Text(text),
      ],
    );
  }

  static Widget _buildPiecesGrid(List<int> pieces) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (pieces.isEmpty) return const SizedBox.shrink();
        final maxWidth = constraints.maxWidth;
        final pieceSize = pieces.length > 1000
            ? 4.0
            : (pieces.length > 500 ? 6.0 : 8.0);
        final spacing = 1.0;
        final cols = (maxWidth / (pieceSize + spacing)).floor().clamp(
          1,
          pieces.length,
        );
        final rows = (pieces.length / cols).ceil();
        final gridHeight = rows * (pieceSize + spacing);

        return SizedBox(
          width: maxWidth,
          height: gridHeight,
          child: CustomPaint(
            painter: _PiecesGridPainter(
              pieces: pieces,
              pieceSize: pieceSize,
              spacing: spacing,
              cols: cols,
            ),
          ),
        );
      },
    );
  }
}

/// Compact per-peer piece availability bar decoded from the hex bitfield.
class PeerBitfieldBar extends StatelessWidget {
  const PeerBitfieldBar({super.key, required this.pieces, this.height = 6});

  final List<int> pieces;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _PeerBitfieldBarPainter(pieces)),
    );
  }
}

class _PeerBitfieldBarPainter extends CustomPainter {
  _PeerBitfieldBarPainter(this.pieces);

  final List<int> pieces;

  static const _completeColor = Color(0xFF4CAF50);
  static const _partialColor = Color(0xFFFFEB3B);
  static const _missingColor = Color(0xFF9E9E9E);

  Color _colorFor(int value) {
    if (value >= 15) return _completeColor;
    if (value > 0) return _partialColor;
    return _missingColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pieces.isEmpty) return;
    final pixelCount = size.width.floor().clamp(1, pieces.length);
    final pixelWidth = size.width / pixelCount;
    final paint = Paint();
    for (var i = 0; i < pixelCount; i++) {
      final start = i * pieces.length ~/ pixelCount;
      final end = ((i + 1) * pieces.length / pixelCount).ceil();
      var value = 0;
      for (var pieceIndex = start; pieceIndex < end; pieceIndex++) {
        if (pieces[pieceIndex] > value) {
          value = pieces[pieceIndex];
        }
      }
      paint.color = _colorFor(value);
      canvas.drawRect(
        Rect.fromLTWH(i * pixelWidth, 0, pixelWidth + 0.5, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PeerBitfieldBarPainter oldDelegate) {
    return oldDelegate.pieces != pieces;
  }
}

class _PiecesGridPainter extends CustomPainter {
  final List<int> pieces;
  final double pieceSize;
  final double spacing;
  final int cols;

  _PiecesGridPainter({
    required this.pieces,
    required this.pieceSize,
    required this.spacing,
    required this.cols,
  });

  static const _pieceColors = {
    0: Color(0xFF9E9E9E), // grey
    1: Color(0xFFFF9800), // orange
    2: Color(0xFFFF9800),
    3: Color(0xFFFF9800),
    4: Color(0xFFFFEB3B), // yellow
    5: Color(0xFFFFEB3B),
    6: Color(0xFFFFEB3B),
    7: Color(0xFFFFEB3B),
    8: Color(0xFF8BC34A), // lightGreen
    9: Color(0xFF8BC34A),
    10: Color(0xFF8BC34A),
    11: Color(0xFF8BC34A),
    12: Color(0xFF4CAF50), // green
    13: Color(0xFF4CAF50),
    14: Color(0xFF4CAF50),
    15: Color(0xFF4CAF50),
  };
  static const _defaultColor = Color(0xFF9E9E9E);
  static const _borderColor = Color(0x1A000000);

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = _borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final fillPaint = Paint();

    for (var i = 0; i < pieces.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final x = col * (pieceSize + spacing);
      final y = row * (pieceSize + spacing);
      final rect = Rect.fromLTWH(x, y, pieceSize, pieceSize);

      fillPaint.color = _pieceColors[pieces[i]] ?? _defaultColor;
      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PiecesGridPainter oldDelegate) {
    return oldDelegate.pieces != pieces;
  }
}

class TaskDetailsTorrentOverviewMetadata {
  final String? comment;
  final DateTime? creationDate;

  const TaskDetailsTorrentOverviewMetadata({this.comment, this.creationDate});
}
