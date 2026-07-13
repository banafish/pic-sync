import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import '../models/settings.dart';
import '../services/discovery_service.dart';
import '../services/http_client.dart';
import '../services/http_server.dart' as srv;
import '../services/settings_store.dart';

class AppState extends ChangeNotifier {
  AppState({required this.store, required this.settings});

  final SettingsStore store;
  final Settings settings;

  srv.HttpServer? server;
  DiscoveryService? discovery;
  int? serverPort;
  String? startupError;
  List<Device> devices = const [];
  StreamSubscription<List<Device>>? _devSub;

  /// UI 注入：弹出配对确认框，返回是否同意。
  Future<bool> Function(String peerId, String peerName)? pairApprover;

  Future<void> startServices() async {
    try {
      final s = srv.HttpServer(
        shareDirs: () => settings.shareDirs,
        deviceInfo: () => (deviceId: settings.deviceId, name: settings.deviceName),
        validateToken: (t) => t != null && settings.issuedTokens.containsValue(t),
        onPairRequest: handlePairRequest,
      );
      serverPort = await s.start();
      server = s;
      final d = DiscoveryService(
        selfInfo: () => (deviceId: settings.deviceId, name: settings.deviceName),
        httpPort: () => serverPort!,
      );
      _devSub = d.devices.listen(updateDevices);
      await d.start();
      discovery = d;
    } catch (e) {
      startupError = '服务启动失败：$e';
    }
    notifyListeners();
  }

  @visibleForTesting
  void updateDevices(List<Device> list) {
    final sorted = list.toList()..sort((a, b) => a.name.compareTo(b.name));
    devices = List.unmodifiable(sorted);
    notifyListeners();
  }

  /// 服务端收到 /pair 时回调：征求用户同意，同意则签发并保存 token。
  Future<String?> handlePairRequest(String peerId, String peerName) async {
    final approver = pairApprover;
    if (approver == null) return null;
    bool ok;
    try {
      ok = await approver(peerId, peerName)
          .timeout(const Duration(seconds: 60), onTimeout: () => false);
    } catch (_) {
      return null;
    }
    if (!ok) return null;
    final token = const Uuid().v4();
    settings.issuedTokens[peerId] = token;
    settings.peerNames[peerId] = peerName;
    await store.save(settings);
    return token;
  }

  /// 取得与对方通信的客户端；无 token 则先配对（会在对方屏幕弹窗等待）。
  Future<PeerClient> connect(Device device) async {
    final client = PeerClient(device.host, device.httpPort,
        token: settings.peerTokens[device.deviceId]);
    if (client.token == null) {
      final token = await client.pair(settings.deviceId, settings.deviceName);
      client.token = token;
      settings.peerTokens[device.deviceId] = token;
      settings.peerNames[device.deviceId] = device.name;
      await store.save(settings);
    }
    return client;
  }

  Future<void> forgetPeerToken(String deviceId) async {
    settings.peerTokens.remove(deviceId);
    await store.save(settings);
  }

  Future<void> addShareDir(String path) async {
    if (settings.shareDirs.contains(path)) return;
    settings.shareDirs.add(path);
    await store.save(settings);
    notifyListeners();
  }

  Future<void> removeShareDir(String path) async {
    settings.shareDirs.remove(path);
    await store.save(settings);
    notifyListeners();
  }

  Future<void> setDefaultRecvDir(String path) async {
    settings.defaultRecvDir = path;
    await store.save(settings);
    notifyListeners();
  }

  Future<void> setDeviceName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    settings.deviceName = n;
    await store.save(settings);
    notifyListeners();
  }

  Future<void> addManualHost(String raw) async {
    final r = raw.trim();
    if (r.isEmpty || settings.manualHosts.contains(r)) return;
    settings.manualHosts.add(r);
    await store.save(settings);
    notifyListeners();
  }

  Future<void> removeManualHost(String raw) async {
    settings.manualHosts.remove(raw);
    await store.save(settings);
    notifyListeners();
  }

  /// "192.168.1.9" 或 "192.168.1.9:45656" → (host, port)，默认端口 45655。
  static (String, int) parseHostPort(String raw) {
    final i = raw.lastIndexOf(':');
    if (i > 0) {
      final port = int.tryParse(raw.substring(i + 1));
      if (port != null) return (raw.substring(0, i), port);
    }
    return (raw, 45655);
  }

  /// 探测手动 IP：成功返回 Device 并挂进设备列表。
  Future<Device> probeManualHost(String raw) async {
    final (host, port) = parseHostPort(raw);
    final info = await PeerClient(host, port).fetchInfo();
    final device = Device(
      deviceId: info.deviceId,
      name: info.name,
      host: host,
      httpPort: port,
      manual: true,
      lastSeen: DateTime.now(),
    );
    discovery?.upsertManual(device);
    return device;
  }

  @override
  void dispose() {
    _devSub?.cancel();
    discovery?.stop();
    server?.stop();
    super.dispose();
  }
}
