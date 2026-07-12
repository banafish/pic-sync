class Device {
  final String deviceId;
  final String name;
  final String host;
  final int httpPort;
  final bool manual;
  final DateTime lastSeen;
  const Device({
    required this.deviceId,
    required this.name,
    required this.host,
    required this.httpPort,
    this.manual = false,
    required this.lastSeen,
  });

  Device copyWith({String? name, String? host, int? httpPort, DateTime? lastSeen}) => Device(
        deviceId: deviceId,
        name: name ?? this.name,
        host: host ?? this.host,
        httpPort: httpPort ?? this.httpPort,
        manual: manual,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}
