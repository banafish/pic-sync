import 'package:flutter_test/flutter_test.dart';
import 'package:pic_sync/models/manifest.dart';
import 'package:pic_sync/services/diff_engine.dart';
import 'package:pic_sync/ui/selection_model.dart';

ManifestFile mf(String name, String folder, [int size = 10]) =>
    ManifestFile(path: '0/$folder/$name', name: name, folder: folder, size: size);

void main() {
  DiffResult diff() => computeMissing(
      [mf('a.jpg', '旅行'), mf('b.jpg', '旅行'), mf('c.jpg', '美食', 5)], const []);

  test('构造时默认全选', () {
    final m = SelectionModel(diff());
    expect(m.selectedCount, 3);
    expect(m.selectedBytes, 25);
    expect(m.folderFullySelected('旅行'), isTrue);
  });

  test('toggleFile 反选单个', () {
    final m = SelectionModel(diff());
    m.toggleFile(mf('a.jpg', '旅行'));
    expect(m.selectedCount, 2);
    expect(m.folderFullySelected('旅行'), isFalse);
    expect(m.selectedCountIn('旅行'), 1);
    m.toggleFile(mf('a.jpg', '旅行'));
    expect(m.selectedCount, 3);
  });

  test('toggleFolder 全不选↔全选', () {
    final m = SelectionModel(diff());
    m.toggleFolder('旅行');
    expect(m.selectedCountIn('旅行'), 0);
    expect(m.selectedCountIn('美食'), 1);
    m.toggleFolder('旅行');
    expect(m.selectedCountIn('旅行'), 2);
  });

  test('selectedFiles 只含选中项', () {
    final m = SelectionModel(diff());
    m.toggleFolder('美食');
    expect(m.selectedFiles.map((f) => f.name), ['a.jpg', 'b.jpg']);
  });
}
