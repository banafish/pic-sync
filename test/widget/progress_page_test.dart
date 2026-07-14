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

    expect(find.text('同步完成'), findsOneWidget);
    expect(find.textContaining('成功 1'), findsOneWidget);
    expect(find.textContaining('失败 1'), findsOneWidget);
    expect(find.text('模拟失败'), findsOneWidget);

    await tester.tap(find.textContaining('重试失败项'));
    await tester.pumpAndSettle();
    expect(find.textContaining('失败 0'), findsOneWidget);
    expect(find.textContaining('重试失败项'), findsNothing);
  });
}
