import 'dart:convert';

class AnnounceMessage {
  final String deviceId;
  final String name;
  final int httpPort;
  const AnnounceMessage({required this.deviceId, required this.name, required this.httpPort});

  String encode() => jsonEncode(
      {'app': 'picsync', 'ver': 1, 'deviceId': deviceId, 'name': name, 'httpPort': httpPort});

  static AnnounceMessage? tryParse(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, dynamic>) return null;
      if (m['app'] != 'picsync' || m['ver'] != 1) return null;
      final id = m['deviceId'];
      final name = m['name'];
      final port = m['httpPort'];
      if (id is! String || name is! String || port is! int) return null;
      return AnnounceMessage(deviceId: id, name: name, httpPort: port);
    } catch (_) {
      return null;
    }
  }
}
