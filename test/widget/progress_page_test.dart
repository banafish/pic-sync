import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pic_sync/models/manifest.dart';
import 'package:pic_sync/services/http_client.dart';
import 'package:pic_sync/services/sync_engine.dart';
import 'package:pic_sync/ui/progress_page.dart';

/// 假客户端：按文件名决定成功或失败；第二次调用同一文件则成功（供重试测试）。
class FakeClient implements PeerClient {
  @override
  String? token;
  @override
  String get host => '127.0.0.1';
  @override
  int get port => 1;
  final Set<String> failedOnce = {};

  @override
  Future<({String deviceId, String name})> fetchInfo() async =>
      (deviceId: 'x', name: 'x');
  @override
  Future<String> pair(String myDeviceId, String myName) async => 't';
  @override
  Future<Manifest> fetchManifest() async =>
      const Manifest(deviceId: 'x', name: 'x', files: []);
  @override
  Future<void> downloadFile({
    required String remotePath,
    required String targetDir,
    required String fileName,
    required int expectedSize,
    void Function(int received)? onProgress,
  }) async {
    if (fileName.startsWith('bad') && !failedOnce.contains(fileName)) {
      failedOnce.add(fileName);
      throw DownloadError('模拟失败');
    }
    onProgress?.call(expectedSize);
  }
}

ManifestFile mf(String name) =>
    ManifestFile(path: '0/x/$name', name: name, folder: 'x', size: 10);

void main() {
  testWidgets('完成后显示摘要；失败可重试', (tester) async {
    final engine = SyncEngine(
      client: FakeClient(),
      shareDirs: const [],
      defaultRecvDir: Directory.systemTemp.path,
    );
    await tester.pumpWidget(MaterialApp(
        home: ProgressPage(engine: engine, files: [mf('ok.jpg'), mf('bad.jpg')])));
    await tester.pumpAndSettle();

    expect(find.text('同步有失败'), findsOneWidget);
    expect(find.text('有失败'), findsOneWidget);
    expect(find.textContaining('成功 1'), findsOneWidget);
    expect(find.textContaining('失败 1'), findsOneWidget);
    expect(find.text('模拟失败'), findsOneWidget);

    await tester.tap(find.textContaining('重试失败项'));
    await tester.pumpAndSettle();
    expect(find.text('同步完成'), findsOneWidget);
    expect(find.text('已传完'), findsOneWidget);
    expect(find.textContaining('失败 0'), findsOneWidget);
    expect(find.textContaining('重试失败项'), findsNothing);
  });

  testWidgets('按文件夹归类展示且可折叠/展开', (tester) async {
    final engine = SyncEngine(
      client: FakeClient(),
      shareDirs: const [],
      defaultRecvDir: Directory.systemTemp.path,
    );
    final f1 = ManifestFile(path: 'p1', name: 'photo1.jpg', folder: '相册A', size: 100);
    final f2 = ManifestFile(path: 'p2', name: 'photo2.jpg', folder: '相册B', size: 200);

    await tester.pumpWidget(MaterialApp(
      home: ProgressPage(engine: engine, files: [f1, f2]),
    ));
    await tester.pumpAndSettle();

    expect(find.text('相册A'), findsOneWidget);
    expect(find.text('相册B'), findsOneWidget);
    expect(find.text('photo1.jpg'), findsOneWidget);
    expect(find.text('photo2.jpg'), findsOneWidget);

    // 折叠相册A
    await tester.tap(find.text('相册A'));
    await tester.pumpAndSettle();

    expect(find.text('photo1.jpg'), findsNothing);
    expect(find.text('photo2.jpg'), findsOneWidget);

    // 重新展开相册A
    await tester.tap(find.text('相册A'));
    await tester.pumpAndSettle();

    expect(find.text('photo1.jpg'), findsOneWidget);
  });
}
