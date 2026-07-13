import 'dart:convert';
import 'dart:io' as io;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../models/manifest.dart';
import 'library_scanner.dart';

typedef ShareDirsProvider = List<String> Function();
typedef DeviceInfoProvider = ({String deviceId, String name}) Function();
typedef TokenValidator = bool Function(String? token);
typedef PairRequestHandler = Future<String?> Function(String peerId, String peerName);

/// 将 manifest 的 "<序号>/<相对路径>" 解析回绝对路径；非法返回 null。
String? pathToAbs(String manifestPath, List<String> shareDirs) {
  final slash = manifestPath.indexOf('/');
  if (slash <= 0) return null;
  final idx = int.tryParse(manifestPath.substring(0, slash));
  if (idx == null || idx < 0 || idx >= shareDirs.length) return null;
  final rel = manifestPath.substring(slash + 1);
  if (rel.isEmpty || rel.contains('..') || p.isAbsolute(rel)) return null;
  final root = p.normalize(io.Directory(shareDirs[idx]).absolute.path);
  final abs = p.normalize(p.join(root, rel));
  if (!p.isWithin(root, abs)) return null;
  return abs;
}

class HttpServer {
  HttpServer({
    required this.shareDirs,
    required this.deviceInfo,
    required this.validateToken,
    required this.onPairRequest,
  });

  final ShareDirsProvider shareDirs;
  final DeviceInfoProvider deviceInfo;
  final TokenValidator validateToken;
  final PairRequestHandler onPairRequest;

  io.HttpServer? _server;
  int _port = 0;
  int get port => _port;

  Future<int> start({int basePort = 45655}) async {
    final router = _router();
    for (var i = 0; i < 10; i++) {
      final candidate = basePort + i;
      try {
        _server = await shelf_io.serve(router.call, io.InternetAddress.anyIPv4, candidate);
        _port = candidate;
        return _port;
      } on io.SocketException {
        continue;
      }
    }
    throw StateError('无法在 $basePort..${basePort + 9} 绑定 HTTP 端口');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Router _router() {
    final r = Router();
    r.get('/info', (Request req) {
      final info = deviceInfo();
      return _json({'deviceId': info.deviceId, 'name': info.name, 'ver': 1});
    });
    r.get('/manifest', (Request req) async {
      if (!_authed(req)) return Response(401);
      return _manifestResponse();
    });
    r.get('/file', (Request req) async {
      if (!_authed(req)) return Response(401);
      final rel = req.url.queryParameters['path'];
      if (rel == null) return Response(400);
      final abs = pathToAbs(rel, shareDirs());
      if (abs == null) return Response(403);
      final file = io.File(abs);
      if (!await file.exists()) return Response(404);
      return Response.ok(file.openRead(), headers: {
        'Content-Length': '${await file.length()}',
        'Content-Type': 'application/octet-stream',
      });
    });
    _registerPair(r);
    return r;
  }

  void _registerPair(Router r) {
    // Task 8 实现 POST /pair
  }

  // shelf 的 headers 不区分大小写，这里统一用小写键读取
  bool _authed(Request req) => validateToken(req.headers['x-picsync-token']);

  Future<Response> _manifestResponse() async {
    final dirs = shareDirs();
    final entries = await LibraryScanner().scan(dirs);
    final normDirs =
        dirs.map((d) => p.normalize(io.Directory(d).absolute.path)).toList();
    final files = <ManifestFile>[];
    for (final e in entries) {
      final idx = normDirs.indexWhere((root) => p.isWithin(root, e.absPath));
      if (idx < 0) continue;
      final rel = p.relative(e.absPath, from: normDirs[idx]).replaceAll(r'\', '/');
      files.add(ManifestFile(path: '$idx/$rel', name: e.name, folder: e.folder, size: e.size));
    }
    final info = deviceInfo();
    return _json(Manifest(deviceId: info.deviceId, name: info.name, files: files).toJson());
  }

  Response _json(Object data) => Response.ok(jsonEncode(data),
      headers: {'Content-Type': 'application/json; charset=utf-8'});
}
