import 'dart:io';

String defaultDeviceType() {
  try {
    if (Platform.isAndroid || Platform.isIOS) return 'phone';
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) return 'desktop';
  } catch (_) {}
  return 'phone';
}

class Device {
  final String deviceId;
  final String name;
  final String host;
  final int httpPort;
  final String deviceType;
  final bool manual;
  final DateTime lastSeen;
  const Device({
    required this.deviceId,
    required this.name,
    required this.host,
    required this.httpPort,
    this.deviceType = 'phone',
    this.manual = false,
    required this.lastSeen,
  });

  Device copyWith({
    String? name,
    String? host,
    int? httpPort,
    String? deviceType,
    DateTime? lastSeen,
  }) =>
      Device(
        deviceId: deviceId,
        name: name ?? this.name,
        host: host ?? this.host,
        httpPort: httpPort ?? this.httpPort,
        deviceType: deviceType ?? this.deviceType,
        manual: manual,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}
