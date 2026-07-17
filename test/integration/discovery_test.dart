import 'package:flutter_test/flutter_test.dart';
import 'package:pic_sync/models/announce.dart';
import 'package:pic_sync/services/discovery_service.dart';

void main() {
  test('ingest 新设备后出现在列表，忽略自身', () async {
    var now = DateTime(2026, 1, 1, 0, 0, 0);
    final d = DiscoveryService(
      selfInfo: () => (deviceId: 'self', name: '我', deviceType: 'phone'),
      httpPort: () => 45655,
      nowFn: () => now,
    );
    final other =
        const AnnounceMessage(deviceId: 'peer', name: '电脑', deviceType: 'desktop', httpPort: 45660)
            .encode();
    final self =
        const AnnounceMessage(deviceId: 'self', name: '我', deviceType: 'phone', httpPort: 45655)
            .encode();

    d.ingest(self, '127.0.0.1'); // 应被忽略
    d.ingest(other, '192.168.1.5');
    expect(d.currentDevices.map((e) => e.deviceId), ['peer']);
    expect(d.currentDevices.single.host, '192.168.1.5');
    expect(d.currentDevices.single.httpPort, 45660);
    expect(d.currentDevices.single.deviceType, 'desktop');
  });

  test('超过 10 秒未刷新则剔除', () async {
    var now = DateTime(2026, 1, 1, 0, 0, 0);
    final d = DiscoveryService(
      selfInfo: () => (deviceId: 'self', name: '我', deviceType: 'phone'),
      httpPort: () => 45655,
      nowFn: () => now,
    );
    d.ingest(const AnnounceMessage(deviceId: 'p', name: 'x', httpPort: 1).encode(), '10.0.0.2');
    expect(d.currentDevices, hasLength(1));
    now = now.add(const Duration(seconds: 11));
    d.pruneStale();
    expect(d.currentDevices, isEmpty);
  });

  test('重复 ingest 更新 lastSeen 与 host', () {
    var now = DateTime(2026, 1, 1);
    final d = DiscoveryService(
      selfInfo: () => (deviceId: 'self', name: '我', deviceType: 'phone'),
      httpPort: () => 45655,
      nowFn: () => now,
    );
    d.ingest(const AnnounceMessage(deviceId: 'p', name: 'x', httpPort: 1).encode(), '10.0.0.2');
    now = now.add(const Duration(seconds: 5));
    d.ingest(const AnnounceMessage(deviceId: 'p', name: 'x2', httpPort: 2).encode(), '10.0.0.9');
    expect(d.currentDevices.single.host, '10.0.0.9');
    expect(d.currentDevices.single.name, 'x2');
  });
}
