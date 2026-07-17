import 'dart:io';
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

  Future<AppState> makeApp() async {
    final store = SettingsStore(p.join(tmp.path, 'settings.json'));
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
}
