import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:pic_sync/services/settings_store.dart';
import 'package:pic_sync/ui/app_state.dart';
import 'package:pic_sync/ui/directory_picker.dart';
import 'package:pic_sync/ui/share_settings_page.dart';

class FakePicker implements DirectoryPicker {
  FakePicker(this.result);
  final String? result;
  @override
  Future<String?> pickDirectory(BuildContext context) async => result;
}

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('picsync_ui_'));
  tearDown(() async => tmp.delete(recursive: true));

  Future<AppState> makeApp() async {
    final store = SettingsStore(p.join(tmp.path, 'settings.json'));
    return AppState(store: store, settings: await store.load());
  }

  Widget wrap(AppState app, Widget child) =>
      ChangeNotifierProvider.value(value: app, child: MaterialApp(home: child));

  // 在 testWidgets 的 fake-async 区内，dart:io 真实文件读写不会完成，
  // 且在 fake 区内发起的 IO 之后也无法被 runAsync 泵完（其完成回调绑定在 fake 区）。
  // 因此把「点击 → 回调 → store.save 落盘」整段放进 runAsync（真实事件循环）里执行，
  // 待真实 IO 与 notifyListeners 完成后，再回到 fake 区 pumpAndSettle 渲染界面。
  Future<void> tapWithIo(WidgetTester tester, Finder finder) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('添加与删除共享目录', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await tester.pumpWidget(wrap(app, ShareSettingsPage(picker: FakePicker('D:/照片'))));
    await tapWithIo(tester, find.byIcon(Icons.add));
    expect(find.text('D:/照片'), findsOneWidget);
    expect(app.settings.shareDirs, ['D:/照片']);

    await tapWithIo(tester, find.byIcon(Icons.delete_outline));
    expect(app.settings.shareDirs, isEmpty);
  });

  testWidgets('设置默认接收目录', (tester) async {
    final app = (await tester.runAsync(makeApp))!;
    await tester.pumpWidget(wrap(app, ShareSettingsPage(picker: FakePicker('D:/收到'))));
    expect(find.textContaining('未设置'), findsOneWidget);
    await tapWithIo(tester, find.text('默认接收目录'));
    expect(app.settings.defaultRecvDir, 'D:/收到');
    expect(find.text('D:/收到'), findsOneWidget);
  });
}
