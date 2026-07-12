import 'package:flutter_test/flutter_test.dart';
import 'package:pic_sync/models/file_entry.dart';
import 'package:pic_sync/models/manifest.dart';
import 'package:pic_sync/services/diff_engine.dart';

ManifestFile mf(String name, String folder) =>
    ManifestFile(path: '0/$folder/$name', name: name, folder: folder, size: 1);

FileEntry fe(String name, String folder) =>
    FileEntry(name: name, size: 1, folder: folder, absPath: '/local/$folder/$name');

void main() {
  test('检出缺失，同名跳过', () {
    final diff = computeMissing(
      [mf('a.jpg', '旅行'), mf('b.jpg', '旅行')],
      [fe('a.jpg', '别处')],
    );
    expect(diff.missing.map((f) => f.name), ['b.jpg']);
  });

  test('大小写不敏感', () {
    final diff = computeMissing([mf('IMG_1.JPG', 'x')], [fe('img_1.jpg', 'y')]);
    expect(diff.missing, isEmpty);
  });

  test('跨文件夹同名视为已存在（全局比对）', () {
    final diff = computeMissing([mf('same.png', '美食')], [fe('same.png', '旅行')]);
    expect(diff.missing, isEmpty);
  });

  test('byFolder 分组且保持首现顺序', () {
    final diff = computeMissing(
      [mf('1.jpg', 'B'), mf('2.jpg', 'A'), mf('3.jpg', 'B')],
      const <FileEntry>[],
    );
    expect(diff.byFolder.keys.toList(), ['B', 'A']);
    expect(diff.byFolder['B']!.map((f) => f.name), ['1.jpg', '3.jpg']);
  });

  test('远端为空则无缺失', () {
    final diff = computeMissing(const [], [fe('a.jpg', 'x')]);
    expect(diff.missing, isEmpty);
    expect(diff.byFolder, isEmpty);
  });
}
