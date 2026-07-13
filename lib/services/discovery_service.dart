import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/announce.dart';
import '../models/device.dart';

const int kDiscoveryPort = 45654;

class DiscoveryService {
  DiscoveryService({required this.selfInfo, required this.httpPort, DateTime Function()? nowFn})
      : nowFn = nowFn ?? DateTime.now;

  final ({String deviceId, String name}) Function() selfInfo;
  final int Function() httpPort;
  final DateTime Function() nowFn;

  final Map<String, Device> _devices = {};
  final StreamController<List<Device>> _controller = StreamController.broadcast();
  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  Timer? _pruneTimer;

  Stream<List<Device>> get devices => _controller.stream;
  List<Device> get currentDevices => _devices.values.toList();

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kDiscoveryPort,
        reuseAddress: true);
    _socket!.broadcastEnabled = true;
    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = _socket!.receive();
      if (dg == null) return;
      // UDP 报文按 UTF-8 解码（设备名可能是中文）
      ingest(utf8.decode(dg.data, allowMalformed: true), dg.address.address);
    });
    _announceTimer = Timer.periodic(const Duration(seconds: 3), (_) => _broadcast());
    _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) => pruneStale());
    _broadcast();
  }

  Future<void> stop() async {
    _announceTimer?.cancel();
    _pruneTimer?.cancel();
    _socket?.close();
    _socket = null;
  }

  void _broadcast() {
    final info = selfInfo();
    final msg = AnnounceMessage(deviceId: info.deviceId, name: info.name, httpPort: httpPort())
        .encode();
    final data = utf8.encode(msg); // 中文设备名需 UTF-8 编码
    _socket?.send(data, InternetAddress('255.255.255.255'), kDiscoveryPort);
  }

  void ingest(String raw, String senderHost) {
    final msg = AnnounceMessage.tryParse(raw);
    if (msg == null) return;
    if (msg.deviceId == selfInfo().deviceId) return;
    _devices[msg.deviceId] = Device(
      deviceId: msg.deviceId,
      name: msg.name,
      host: senderHost,
      httpPort: msg.httpPort,
      lastSeen: nowFn(),
    );
    _emit();
  }

  void pruneStale() {
    final cutoff = nowFn().subtract(const Duration(seconds: 10));
    final before = _devices.length;
    _devices.removeWhere((_, d) => d.manual ? false : d.lastSeen.isBefore(cutoff));
    if (_devices.length != before) _emit();
  }

  void upsertManual(Device device) {
    _devices[device.deviceId] = device;
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) _controller.add(currentDevices);
  }
}
