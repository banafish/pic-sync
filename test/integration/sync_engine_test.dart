import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/models/manifest.dart';
import 'package:pic_sync/services/http_server.dart' as srv;
import 'package:pic_sync/services/http_client.dart';
import 'package:pic_sync/services/sync_engine.dart';

/// 模拟磁盘满的假客户端（供中止测试）。
class DiskFullClient implements PeerClient {
  @override
  String? token;
  @override
  String get host => '127.0.0.1';
  @override
  int get port => 1;
  @override
  Future<({String deviceId, String name, String deviceType})> fetchInfo({
    ({String deviceId, String name, String deviceType, int httpPort})? selfInfo,
  }) async =>
      (deviceId: 'x', name: 'x', deviceType: 'phone');
  @override
  Future<String> pair(String myDeviceId, String myName) async => 't';
  @override
  Future<Manifest> fetchManifest() async => const Manifest(deviceId: 'x', name: 'x', files: []);
  @override
  Future<void> downloadFile({
    required String remotePath,
    required String targetDir,
    required String fileName,
    required int expectedSize,
    void Function(int received)? onProgress,
  }) async {
    throw const FileSystemException('写入失败', 'x', OSError('no space left', 28));
  }
}

void main() {
  late Directory remote;
  late Directory local;
  late srv.HttpServer server;
  late int port;

  setUp(() async {
    remote = await Directory.systemTemp.createTemp('picsync_remote_');
    local = await Directory.systemTemp.createTemp('picsync_local_');
    // 远端两张图：旅行/a.jpg、美食/b.jpg
    await File(p.join(remote.path, '旅行', 'a.jpg')).create(recursive: true);
    await File(p.join(remote.path, '旅行', 'a.jpg')).writeAsString('aaa');
    await File(p.join(remote.path, '美食', 'b.jpg')).create(recursive: true);
    await File(p.join(remote.path, '美食', 'b.jpg')).writeAsString('bbbb');
    // 本地已有同名文件夹「旅行」
    await Directory(p.join(local.path, '相册', '旅行')).create(recursive: true);
    server = srv.HttpServer(
      shareDirs: () => [remote.path],
      deviceInfo: () => (deviceId: 'srv', name: 'S', deviceType: 'desktop'),
      validateToken: (t) => t == 'tok',
      onPairRequest: (_, _) async => 'tok',
    );
    port = await server.start(basePort: 46300);
  });
  tearDown(() async {
    await server.stop();
    await remote.delete(recursive: true);
    await local.delete(recursive: true);
  });

  test('全部下载：同名进同名目录，其余进默认目录', () async {
    final client = PeerClient('127.0.0.1', port, token: 'tok');
    final manifest = await client.fetchManifest();
    final def = p.join(local.path, '默认');
    final engine = SyncEngine(
      client: client,
      shareDirs: [p.join(local.path, '相册')],
      defaultRecvDir: def,
    );
    final results = await engine.run(manifest.files);
    expect(results.where((r) => r.status == SyncStatus.done), hasLength(2));
    // a.jpg -> 相册/旅行/a.jpg
    expect(File(p.join(local.path, '相册', '旅行', 'a.jpg')).existsSync(), isTrue);
    // b.jpg -> 默认/b.jpg（无同名目录「美食」）
    expect(File(p.join(def, 'b.jpg')).existsSync(), isTrue);
  });

  test('单项失败不影响其余；远端补上后 retry 成功', () async {
    final client = PeerClient('127.0.0.1', port, token: 'tok');
    final manifest = await client.fetchManifest();
    // 远端清单里伪造一个此刻不存在的文件 → 该项 404 失败，其余正常
    const ghost = ManifestFile(path: '0/旅行/ghost.jpg', name: 'ghost.jpg', folder: '旅行', size: 5);
    final engine = SyncEngine(
      client: client,
      shareDirs: [p.join(local.path, '相册')],
      defaultRecvDir: p.join(local.path, '默认'),
    );
    final results = await engine.run([...manifest.files, ghost]);
    expect(results.where((r) => r.status == SyncStatus.done), hasLength(2));
    final failed = results.where((r) => r.status == SyncStatus.failed).toList();
    expect(failed.single.file.name, 'ghost.jpg');
    expect(failed.single.error, isNotNull);

    // 远端补上该文件（内容 5 字节，与 size 一致）后重试成功
    await File(p.join(remote.path, '旅行', 'ghost.jpg')).writeAsString('ghost');
    final retried = await engine.retry(failed);
    expect(retried.single.status, SyncStatus.done);
    expect(File(p.join(local.path, '相册', '旅行', 'ghost.jpg')).existsSync(), isTrue);
  });

  test('进度流报告字节数', () async {
    final client = PeerClient('127.0.0.1', port, token: 'tok');
    final manifest = await client.fetchManifest();
    final engine = SyncEngine(
      client: client,
      shareDirs: const [],
      defaultRecvDir: p.join(local.path, '默认'),
    );
    final events = <SyncProgress>[];
    final sub = engine.progress.listen(events.add);
    await engine.run(manifest.files);
    // 广播流为异步派发：run() 结束时最后几条事件已 add 但尚未送达监听者，
    // 立即 cancel 会丢弃它们。先 pump 事件队列，让末条 completed=2 事件送达。
    await pumpEventQueue();
    await sub.cancel();
    expect(events.last.totalBytes, 7); // aaa(3) + bbbb(4)
    expect(events.last.receivedBytes, 7);
    expect(events.last.completed, 2);
  });

  test('磁盘满时中止队列，剩余项保持 pending', () async {
    final engine = SyncEngine(
      client: DiskFullClient(),
      shareDirs: const [],
      defaultRecvDir: p.join(local.path, '默认'),
      concurrency: 1,
    );
    ManifestFile mf(String name) =>
        ManifestFile(path: '0/x/$name', name: name, folder: 'x', size: 1);
    final results = await engine.run([mf('1.jpg'), mf('2.jpg'), mf('3.jpg')]);
    expect(engine.abortedDiskFull, isTrue);
    expect(results.first.status, SyncStatus.failed);
    expect(results.first.error, '磁盘空间不足');
    expect(results.where((r) => r.status == SyncStatus.pending), isNotEmpty);
  });
}
