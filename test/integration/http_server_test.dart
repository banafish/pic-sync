import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/services/http_server.dart' as srv;

void main() {
  late Directory tmp;
  late srv.HttpServer server;
  late int port;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('picsync_http_');
    final seed = File(p.join(tmp.path, '旅行', 'a.jpg'));
    await seed.create(recursive: true);
    await seed.writeAsString('hello');
    server = srv.HttpServer(
      shareDirs: () => [tmp.path],
      deviceInfo: () => (deviceId: 'srv-id', name: '服务端', deviceType: 'desktop'),
      validateToken: (t) => t == 'good-token',
      onPairRequest: (id, name) async => null,
    );
    port = await server.start(basePort: 46000);
  });
  tearDown(() async {
    await server.stop();
    await tmp.delete(recursive: true);
  });

  Future<HttpClientResponse> get(String path, {String? token}) async {
    final c = HttpClient();
    final req = await c.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
    if (token != null) req.headers.set('X-PicSync-Token', token);
    return req.close();
  }

  test('/info 免鉴权', () async {
    final res = await get('/info');
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.transform(utf8.decoder).join());
    expect(body['deviceId'], 'srv-id');
    expect(body['ver'], 1);
  });

  test('/manifest 无 token 返回 401', () async {
    final res = await get('/manifest');
    expect(res.statusCode, 401);
  });

  test('/manifest 有 token 返回清单', () async {
    final res = await get('/manifest', token: 'good-token');
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.transform(utf8.decoder).join());
    expect(body['files'], hasLength(1));
    expect(body['files'][0]['name'], 'a.jpg');
    expect(body['files'][0]['folder'], '旅行');
    expect(body['files'][0]['path'], '0/旅行/a.jpg');
  });

  test('/file 下载内容正确', () async {
    final res = await get('/file?path=${Uri.encodeQueryComponent('0/旅行/a.jpg')}', token: 'good-token');
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join(), 'hello');
  });

  test('/file 目录穿越被拒', () async {
    final res = await get('/file?path=${Uri.encodeQueryComponent('0/../../etc/passwd')}', token: 'good-token');
    expect(res.statusCode, 403);
  });

  test('/file 不存在返回 404', () async {
    final res = await get('/file?path=${Uri.encodeQueryComponent('0/旅行/none.jpg')}', token: 'good-token');
    expect(res.statusCode, 404);
  });
}
