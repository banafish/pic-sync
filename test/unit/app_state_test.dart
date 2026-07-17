import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/models/device.dart';
import 'package:pic_sync/services/http_server.dart' as srv;
import 'package:pic_sync/services/settings_store.dart';
import 'package:pic_sync/ui/app_state.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('picsync_app_'));
  tearDown(() async => tmp.delete(recursive: true));

  Future<AppState> makeApp([String filename = 'settings.json']) async {
    final store = SettingsStore(p.join(tmp.path, filename));
    return AppState(store: store, settings: await store.load());
  }

  test('parseHostPort', () {
    expect(AppState.parseHostPort('192.168.1.9'), ('192.168.1.9', 45655));
    expect(AppState.parseHostPort('192.168.1.9:46000'), ('192.168.1.9', 46000));
  });

  test('addShareDir 持久化且去重', () async {
    final app = await makeApp();
    await app.addShareDir('D:/照片');
    await app.addShareDir('D:/照片');
    expect(app.settings.shareDirs, ['D:/照片']);
    final reloaded = await SettingsStore(p.join(tmp.path, 'settings.json')).load();
    expect(reloaded.shareDirs, ['D:/照片']);
  });

  test('handlePairRequest 同意签发并持久化，拒绝返回 null', () async {
    final app = await makeApp();
    app.pairApprover = (id, name) async => true;
    final token = await app.handlePairRequest('peer1', '手机');
    expect(token, isNotNull);
    expect(app.settings.issuedTokens['peer1'], token);
    app.pairApprover = (id, name) async => false;
    expect(await app.handlePairRequest('peer2', 'x'), isNull);
    expect(app.settings.issuedTokens.containsKey('peer2'), isFalse);
  });

  test('connect 首次配对并保存 token，二次直连', () async {
    var pairCalls = 0;
    final server = srv.HttpServer(
      shareDirs: () => [],
      deviceInfo: () => (deviceId: 'srv-id', name: 'S', deviceType: 'desktop'),
      validateToken: (t) => t == 'issued',
      onPairRequest: (id, name) async {
        pairCalls++;
        return 'issued';
      },
    );
    final port = await server.start(basePort: 46400);
    final app = await makeApp();
    final device = Device(
        deviceId: 'srv-id', name: 'S', host: '127.0.0.1', httpPort: port, lastSeen: DateTime.now());
    final c1 = await app.connect(device);
    expect(c1.token, 'issued');
    final c2 = await app.connect(device);
    expect(c2.token, 'issued');
    expect(pairCalls, 1);
    await server.stop();
  });

  test('setDefaultRecvDir 自动加入 shareDirs 且替换旧默认目录', () async {
    final app = await makeApp();
    await app.setDefaultRecvDir('D:/收到1');
    expect(app.settings.defaultRecvDir, 'D:/收到1');
    expect(app.settings.shareDirs, ['D:/收到1']);

    await app.setDefaultRecvDir('D:/收到2');
    expect(app.settings.defaultRecvDir, 'D:/收到2');
    expect(app.settings.shareDirs, ['D:/收到2']);

    final reloaded = await SettingsStore(p.join(tmp.path, 'settings.json')).load();
    expect(reloaded.defaultRecvDir, 'D:/收到2');
    expect(reloaded.shareDirs, ['D:/收到2']);
  });

  test('removeShareDir 删除默认目录时同时清空 defaultRecvDir', () async {
    final app = await makeApp();
    await app.setDefaultRecvDir('D:/收到');
    await app.addShareDir('D:/其它共享');
    expect(app.settings.shareDirs, ['D:/收到', 'D:/其它共享']);

    await app.removeShareDir('D:/收到');
    expect(app.settings.shareDirs, ['D:/其它共享']);
    expect(app.settings.defaultRecvDir, '');

    final reloaded = await SettingsStore(p.join(tmp.path, 'settings.json')).load();
    expect(reloaded.defaultRecvDir, '');
    expect(reloaded.shareDirs, ['D:/其它共享']);
  });

  test('probeManualHost 探测对方时对方与本机相互添加设备', () async {
    final app1 = await makeApp('s1.json');
    await app1.startServices();

    final app2 = await makeApp('s2.json');
    await app2.startServices();

    final dev2 = await app1.probeManualHost('127.0.0.1:${app2.serverPort}');
    expect(dev2.deviceId, app2.settings.deviceId);
    expect(app1.discovery?.currentDevices.any((d) => d.deviceId == app2.settings.deviceId), isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(app2.discovery?.currentDevices.any((d) => d.deviceId == app1.settings.deviceId), isTrue);
    final expectedHost = app1.serverPort == 45655 ? '127.0.0.1' : '127.0.0.1:${app1.serverPort}';
    expect(app2.settings.manualHosts.contains(expectedHost), isTrue);

    app1.dispose();
    app2.dispose();
  });

  test('应用返回前台 (resumed) 时触发 refreshDiscovery 重启 UDP 发现服务', () async {
    final app = await makeApp('s_resume.json');
    await app.startServices();

    final oldDiscovery = app.discovery;
    expect(oldDiscovery, isNotNull);

    app.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(app.discovery, isNotNull);
    app.dispose();
  });
}
