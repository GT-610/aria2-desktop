class Aria2Peer {
  const Aria2Peer({
    this.ip = '',
    this.port,
    this.peerId,
    this.pieces = const <int>[],
    this.isSeeder = false,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
  });

  final String ip;
  final int? port;
  final String? peerId;
  final List<int> pieces;
  final bool isSeeder;
  final int uploadSpeed;
  final int downloadSpeed;

  factory Aria2Peer.fromRpc(Map<Object?, Object?> values) {
    final bitfield = values['bitfield'];
    return Aria2Peer(
      ip: _stringValue(values['ip']),
      port: _portValue(values['port']),
      peerId: _optionalStringValue(values['peerId']),
      pieces: bitfield is String ? _parsePieces(bitfield) : const <int>[],
      isSeeder: _boolValue(values['seeder']),
      uploadSpeed: _nonNegativeIntValue(values['uploadSpeed']),
      downloadSpeed: _nonNegativeIntValue(values['downloadSpeed']),
    );
  }

  static String _stringValue(Object? value) => value is String ? value : '';

  static String? _optionalStringValue(Object? value) {
    final string = _stringValue(value);
    return string.isEmpty ? null : string;
  }

  static int? _portValue(Object? value) {
    final port = _intValue(value);
    return port != null && port > 0 && port <= 65535 ? port : null;
  }

  static int _nonNegativeIntValue(Object? value) {
    final number = _intValue(value);
    return number != null && number > 0 ? number : 0;
  }

  static int? _intValue(Object? value) {
    return switch (value) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };
  }

  static bool _boolValue(Object? value) => value == true || value == 'true';

  static List<int> _parsePieces(String bitfield) {
    final pieces = <int>[];
    for (final character in bitfield.split('')) {
      final piece = int.tryParse(character, radix: 16);
      if (piece == null) {
        return const <int>[];
      }
      pieces.add(piece);
    }
    return List<int>.unmodifiable(pieces);
  }
}
