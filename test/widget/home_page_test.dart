import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:pic_sync/models/device.dart';
import 'package:pic_sync/services/settings_store.dart';
import 'package:pic_sync/ui/app_state.dart';
import 'package:pic_sync/ui/home_page.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('picsync_home_'));
  tearDown(() async => tmp.delete(recursive: true));

  Future<AppState> makeApp() async {
    final store = SettingsStore(p.join(tmp.path, 'settings.json'));
    return AppState(store: store, settings: await store.load());
  }

  Widget wrap(AppState app) => ChangeNotifierProvider.value(
      value: app, child: const MaterialApp(home: HomePage()));

  testWidgets('空态提示', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await tester.pumpWidget(wrap(app));
    expect(find.textContaining('未发现设备'), findsOneWidget);
  });

  testWidgets('设备出现在列表；未设默认目录时点按提示', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await tester.pumpWidget(wrap(app));
    app.updateDevices([
      Device(deviceId: 'd1', name: '手机', host: '192.168.1.5', httpPort: 45655, lastSeen: DateTime.now()),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('手机'), findsOneWidget);

    await tester.tap(find.text('手机'));
    await tester.pumpAndSettle();
    expect(find.textContaining('默认接收目录'), findsOneWidget); // SnackBar 提示
  });
}
