import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/models/device.dart';
import 'package:pic_sync/services/http_server.dart' as srv;
import 'package:pic_sync/services/settings_store.dart';
import 'package:pic_sync/ui/app_state.dart';
import 'package:pic_sync/ui/select_loader.dart';

void main() {
  late Directory tmp;
  late Directory remote;
  late srv.HttpServer server;
  late int port;
  final issued = <String>{};

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('picsync_sl_');
    remote = await Directory.systemTemp.createTemp('picsync_sl_remote_');
    await File(p.join(remote.path, '旅行', 'new.jpg')).create(recursive: true);
    await File(p.join(remote.path, '旅行', 'new.jpg')).writeAsString('n');
    await File(p.join(remote.path, '旅行', 'have.jpg')).create(recursive: true);
    await File(p.join(remote.path, '旅行', 'have.jpg')).writeAsString('h');
    issued.clear();
    server = srv.HttpServer(
      shareDirs: () => [remote.path],
      deviceInfo: () => (deviceId: 'srv-id', name: 'S', deviceType: 'desktop'),
      validateToken: (t) => t != null && issued.contains(t),
      onPairRequest: (id, name) async {
        final t = 'tok-${issued.length}';
        issued.add(t);
        return t;
      },
    );
    port = await server.start(basePort: 46500);
  });
  tearDown(() async {
    await server.stop();
    await tmp.delete(recursive: true);
    await remote.delete(recursive: true);
  });

  Future<AppState> makeApp() async {
    final store = SettingsStore(p.join(tmp.path, 'settings.json'));
    final app = AppState(store: store, settings: await store.load());
    // 本机已有 have.jpg
    final localShare = Directory(p.join(tmp.path, '本机相册'));
    await localShare.create(recursive: true);
    await File(p.join(localShare.path, 'have.jpg')).writeAsString('h');
    app.settings.shareDirs.add(localShare.path);
    return app;
  }

  Device dev() => Device(
      deviceId: 'srv-id', name: 'S', host: '127.0.0.1', httpPort: port, lastSeen: DateTime.now());

  test('加载并比对：只缺 new.jpg，统计远端总数', () async {
    final app = await makeApp();
    final result = await SelectLoader().load(app, dev());
    expect(result.diff.missing.map((f) => f.name), ['new.jpg']);
    expect(result.remotePerFolder['旅行'], 2);
    expect(app.settings.peerTokens['srv-id'], isNotNull);
  });

  test('token 失效时自动重新配对', () async {
    final app = await makeApp();
    app.settings.peerTokens['srv-id'] = 'stale-token-invalid';
    final result = await SelectLoader().load(app, dev());
    expect(result.diff.missing, hasLength(1));
    expect(issued, contains(app.settings.peerTokens['srv-id']));
  });
}
