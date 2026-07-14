import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:pic_sync/models/device.dart';
import 'package:pic_sync/models/manifest.dart';
import 'package:pic_sync/services/diff_engine.dart';
import 'package:pic_sync/services/http_client.dart';
import 'package:pic_sync/services/settings_store.dart';
import 'package:pic_sync/ui/app_state.dart';
import 'package:pic_sync/ui/select_loader.dart';
import 'package:pic_sync/ui/select_page.dart';

class StubLoader implements SelectLoader {
  StubLoader(this.result);
  final SelectLoadResult result;
  @override
  Future<SelectLoadResult> load(AppState app, Device device,
          {void Function(String status)? onStatus}) async =>
      result;
}

void main() {
  testWidgets('展示分组、勾选数与按钮状态', (tester) async {
    late Directory tmp;
    late AppState app;
    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('picsync_sp_');
      final store = SettingsStore(p.join(tmp.path, 'settings.json'));
      app = AppState(store: store, settings: await store.load());
    });
    addTearDown(() => tmp.delete(recursive: true));

    const files = [
      ManifestFile(path: '0/旅行/new.jpg', name: 'new.jpg', folder: '旅行', size: 100),
      ManifestFile(path: '0/旅行/have.jpg', name: 'have.jpg', folder: '旅行', size: 100),
    ];
    // 只有 new.jpg 缺失（have.jpg 假定本机已有，不进 diff）
    final diff = computeMissing([files.first], const []);
    final result = SelectLoadResult(
      client: PeerClient('127.0.0.1', 1),
      manifest: const Manifest(deviceId: 'srv', name: 'S', files: files),
      diff: diff,
      remotePerFolder: const {'旅行': 2},
    );
    final device = Device(
        deviceId: 'srv', name: 'S', host: '127.0.0.1', httpPort: 1, lastSeen: DateTime.now());

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(home: SelectPage(device: device, loader: StubLoader(result))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('旅行'), findsOneWidget);
    expect(find.textContaining('缺 1 / 共 2'), findsOneWidget);
    expect(find.textContaining('1 个文件'), findsOneWidget);

    // 取消勾选整个文件夹后按钮禁用
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '开始同步（0 个文件，0 B）'));
    expect(button.onPressed, isNull);
  });
}
