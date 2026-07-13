import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/services/settings_store.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('picsync_set_'));
  tearDown(() async => tmp.delete(recursive: true));

  test('首次加载生成 deviceId 并落盘', () async {
    final path = p.join(tmp.path, 'settings.json');
    final store = SettingsStore(path);
    final s = await store.load();
    expect(s.deviceId, isNotEmpty);
    expect(s.deviceName, isNotEmpty);
    expect(File(path).existsSync(), isTrue);
  });

  test('保存后重载 deviceId 稳定、内容一致', () async {
    final path = p.join(tmp.path, 'settings.json');
    final store = SettingsStore(path);
    final s = await store.load();
    final id = s.deviceId;
    s.shareDirs.add('D:/照片');
    await store.save(s);
    final again = await SettingsStore(path).load();
    expect(again.deviceId, id);
    expect(again.shareDirs, ['D:/照片']);
  });

  test('JSON 损坏时重建', () async {
    final path = p.join(tmp.path, 'settings.json');
    await File(path).writeAsString('{ 坏 json');
    final s = await SettingsStore(path).load();
    expect(s.deviceId, isNotEmpty);
  });
}
