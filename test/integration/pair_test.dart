import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pic_sync/services/http_server.dart' as srv;

void main() {
  Future<HttpClientResponse> postPair(int port, Map<String, dynamic> body) async {
    final c = HttpClient();
    final req = await c.postUrl(Uri.parse('http://127.0.0.1:$port/pair'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    return req.close();
  }

  test('同意配对返回 token', () async {
    final server = srv.HttpServer(
      shareDirs: () => [],
      deviceInfo: () => (deviceId: 'srv', name: 'S'),
      validateToken: (_) => false,
      onPairRequest: (id, name) async => 'issued-token',
    );
    final port = await server.start(basePort: 46100);
    final res = await postPair(port, {'deviceId': 'peer', 'name': '手机'});
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.transform(utf8.decoder).join());
    expect(body['token'], 'issued-token');
    await server.stop();
  });

  test('拒绝配对返回 403', () async {
    final server = srv.HttpServer(
      shareDirs: () => [],
      deviceInfo: () => (deviceId: 'srv', name: 'S'),
      validateToken: (_) => false,
      onPairRequest: (id, name) async => null,
    );
    final port = await server.start(basePort: 46110);
    final res = await postPair(port, {'deviceId': 'peer', 'name': '手机'});
    expect(res.statusCode, 403);
    await server.stop();
  });
}
