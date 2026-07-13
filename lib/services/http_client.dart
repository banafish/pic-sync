import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/manifest.dart';

class PairRejected implements Exception {}
class Unauthorized implements Exception {}
class DownloadError implements Exception {
  DownloadError(this.message);
  final String message;
  @override
  String toString() => 'DownloadError: $message';
}

class PeerClient {
  PeerClient(this.host, this.port, {this.token});
  final String host;
  final int port;
  String? token;

  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('http://$host:$port$path').replace(queryParameters: query);

  Future<({String deviceId, String name})> fetchInfo() async {
    final req = await _client.getUrl(_uri('/info'));
    final res = await req.close();
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    return (deviceId: body['deviceId'] as String, name: body['name'] as String);
  }

  Future<String> pair(String myDeviceId, String myName) async {
    final req = await _client.postUrl(_uri('/pair'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'deviceId': myDeviceId, 'name': myName}));
    final res = await req.close();
    if (res.statusCode == 403) throw PairRejected();
    if (res.statusCode != 200) throw DownloadError('配对失败：HTTP ${res.statusCode}');
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
    return body['token'] as String;
  }

  Future<Manifest> fetchManifest() async {
    final req = await _client.getUrl(_uri('/manifest'));
    if (token != null) req.headers.set('X-PicSync-Token', token!);
    final res = await req.close();
    if (res.statusCode == 401) throw Unauthorized();
    if (res.statusCode != 200) throw DownloadError('清单请求失败：HTTP ${res.statusCode}');
    return Manifest.fromJson(
        jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>);
  }

  Future<void> downloadFile({
    required String remotePath,
    required String targetDir,
    required String fileName,
    required int expectedSize,
    void Function(int received)? onProgress,
  }) async {
    final finalFile = File(p.join(targetDir, fileName));
    if (await finalFile.exists()) return; // 竞态：已存在则跳过
    await Directory(targetDir).create(recursive: true);
    final part = File(p.join(targetDir, '$fileName.picsync.part'));
    final req = await _client.getUrl(_uri('/file', {'path': remotePath}));
    if (token != null) req.headers.set('X-PicSync-Token', token!);
    final res = await req.close();
    if (res.statusCode != 200) {
      await res.drain<void>().catchError((_) {});
      if (res.statusCode == 401) throw Unauthorized();
      throw DownloadError('下载失败：HTTP ${res.statusCode}');
    }
    final sink = part.openWrite();
    var received = 0;
    try {
      await for (final chunk in res) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received);
      }
      await sink.close();
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
      if (e is FileSystemException) rethrow; // 磁盘满等原始 IO 异常上抛，供 SyncEngine 识别
      throw DownloadError('传输中断：$e');
    }
    final actual = await part.length();
    if (actual != expectedSize) {
      await part.delete();
      throw DownloadError('文件尺寸不符（期望 $expectedSize，实得 $actual）');
    }
    if (await finalFile.exists()) {
      await part.delete(); // 期间被别的下载补上了
      return;
    }
    await part.rename(finalFile.path);
  }
}
