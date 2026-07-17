import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/services/http_server.dart' as srv;
import 'package:pic_sync/services/http_client.dart';

void main() {
  late Directory tmp;
  late Directory dst;
  late srv.HttpServer server;
  late int port;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('picsync_srv_');
    dst = await Directory.systemTemp.createTemp('picsync_dst_');
    await File(p.join(tmp.path, '旅行', 'a.jpg')).create(recursive: true);
    await File(p.join(tmp.path, '旅行', 'a.jpg')).writeAsString('hello-world');
    server = srv.HttpServer(
      shareDirs: () => [tmp.path],
      deviceInfo: () => (deviceId: 'srv', name: '服务端', deviceType: 'desktop'),
      validateToken: (t) => t == 'tok',
      onPairRequest: (id, name) async => 'tok',
    );
    port = await server.start(basePort: 46200);
  });
  tearDown(() async {
    await server.stop();
    await tmp.delete(recursive: true);
    await dst.delete(recursive: true);
  });

  test('fetchInfo', () async {
    final info = await PeerClient('127.0.0.1', port).fetchInfo();
    expect(info.deviceId, 'srv');
  });

  test('pair 返回 token 后可拉清单', () async {
    final c = PeerClient('127.0.0.1', port);
    final token = await c.pair('me', '我');
    expect(token, 'tok');
    c.token = token;
    final m = await c.fetchManifest();
    expect(m.files.single.name, 'a.jpg');
  });

  test('无 token 拉清单抛 Unauthorized', () async {
    expect(() => PeerClient('127.0.0.1', port).fetchManifest(), throwsA(isA<Unauthorized>()));
  });

  test('下载写入并 rename', () async {
    final c = PeerClient('127.0.0.1', port, token: 'tok');
    final m = await c.fetchManifest();
    final f = m.files.single;
    await c.downloadFile(
        remotePath: f.path, targetDir: dst.path, fileName: f.name, expectedSize: f.size);
    final out = File(p.join(dst.path, 'a.jpg'));
    expect(out.existsSync(), isTrue);
    expect(out.readAsStringSync(), 'hello-world');
    expect(File(p.join(dst.path, 'a.jpg.picsync.part')).existsSync(), isFalse);
  });

  test('目标已存在则跳过', () async {
    await File(p.join(dst.path, 'a.jpg')).writeAsString('已存在');
    final c = PeerClient('127.0.0.1', port, token: 'tok');
    final m = await c.fetchManifest();
    await c.downloadFile(
        remotePath: m.files.single.path, targetDir: dst.path, fileName: 'a.jpg', expectedSize: 11);
    expect(File(p.join(dst.path, 'a.jpg')).readAsStringSync(), '已存在');
  });
}
