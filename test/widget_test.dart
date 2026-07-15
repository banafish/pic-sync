import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/main.dart';
import 'package:pic_sync/services/settings_store.dart';
import 'package:pic_sync/ui/app_state.dart';

void main() {
  testWidgets('应用启动显示主页（不启动网络服务）', (tester) async {
    final app = (await tester.runAsync(() async {
      final tmp = await Directory.systemTemp.createTemp('picsync_main_');
      addTearDown(() => tmp.delete(recursive: true));
      final store = SettingsStore(p.join(tmp.path, 'settings.json'));
      return AppState(store: store, settings: await store.load());
    }))!;
    await tester.pumpWidget(PicSyncApp(appState: app));
    expect(find.text('图片同步'), findsOneWidget);
    expect(find.textContaining('未发现设备'), findsOneWidget);
  });
}
