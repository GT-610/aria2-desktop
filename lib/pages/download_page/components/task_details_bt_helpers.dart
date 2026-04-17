import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../utils/format_utils.dart';
import '../models/download_task.dart';

class TaskDetailsBtHelpers {
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

    return Column(
      children: peers.map((peer) {
        final ip = peer['ip']?.toString() ?? '--';
        final port = peer['port']?.toString() ?? '--';
        final peerId = _parsePeerClient(peer['peerId']?.toString());
        final progress = _bitfieldToPercent(peer['bitfield']?.toString());
        final uploadSpeed = formatBytes(
          int.tryParse(peer['uploadSpeed']?.toString() ?? '0') ?? 0,
        );
        final downloadSpeed = formatBytes(
          int.tryParse(peer['downloadSpeed']?.toString() ?? '0') ?? 0,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text('$ip:$port'),
            subtitle: Text(
              '${l10n.clientLabel}: $peerId\n'
              '${l10n.progress}: ${progress.toStringAsFixed(0)}%\n'
              '${l10n.uploadShort}: $uploadSpeed/s  ${l10n.downloadShort}: $downloadSpeed/s',
            ),
          ),
        );
      }).toList(),
    );
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

  static double _bitfieldToPercent(String? bitfield) {
    if (bitfield == null || bitfield.isEmpty) {
      return 0;
    }
    final pieces = parseHexBitfield(bitfield);
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

    final azureusMatch = RegExp(r'^-([A-Za-z~]{2})(.{4})-').firstMatch(decoded);
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
      if (RegExp(r'[0-9]').hasMatch(char)) {
        segments.add(char);
      } else if (RegExp(r'[A-Za-z]').hasMatch(char)) {
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
    final pieceSize = pieces.length > 1000
        ? 4.0
        : (pieces.length > 500 ? 6.0 : 8.0);

    return Wrap(
      spacing: 1,
      runSpacing: 1,
      children: List.generate(pieces.length, (index) {
        return Container(
          width: pieceSize,
          height: pieceSize,
          decoration: BoxDecoration(
            color: _getPieceColor(pieces[index]),
            border: Border.all(
              width: 0.5,
              color: Colors.black.withValues(alpha: 0.1),
            ),
          ),
        );
      }),
    );
  }

  static Color _getPieceColor(int pieceValue) {
    switch (pieceValue) {
      case 0:
        return Colors.grey;
      case 1:
      case 2:
      case 3:
        return Colors.orange;
      case 4:
      case 5:
      case 6:
      case 7:
        return Colors.yellow;
      case 8:
      case 9:
      case 10:
      case 11:
        return Colors.lightGreen;
      case 12:
      case 13:
      case 14:
      case 15:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class TaskDetailsTorrentOverviewMetadata {
  final String? comment;
  final DateTime? creationDate;

  const TaskDetailsTorrentOverviewMetadata({this.comment, this.creationDate});
}
