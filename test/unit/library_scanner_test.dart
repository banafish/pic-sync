import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/services/library_scanner.dart';
import 'package:pic_sync/services/media_types.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('picsync_scan_');
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Future<File> put(String rel, [String content = 'x']) async {
    final f = File(p.join(tmp.path, rel));
    await f.parent.create(recursive: true);
    return f.writeAsString(content);
  }

  test('isMediaFile 按扩展名判定、不区分大小写', () {
    expect(isMediaFile('a.JPG'), isTrue);
    expect(isMediaFile('b.heic'), isTrue);
    expect(isMediaFile('c.Mp4'), isTrue);
    expect(isMediaFile('d.txt'), isFalse);
    expect(isMediaFile('无扩展名'), isFalse);
    expect(isMediaFile('.jpg'), isFalse); // 隐藏文件形态
  });

  test('递归扫描、过滤、folder 归属', () async {
    final shareName = p.basename(tmp.path);
    await put('root.jpg', 'aa');
    await put('旅行/day1/IMG_001.jpg', 'bbb');
    await put('旅行/note.txt');
    await put('旅行/.hidden.jpg');
    await put('.thumb/x.jpg');
    await put('下载/video.mp4', 'cccc');
    await put('下载/tmp.jpg.picsync.part');

    final entries = await LibraryScanner().scan([tmp.path]);
    final names = entries.map((e) => e.name).toList()..sort();
    expect(names, ['IMG_001.jpg', 'root.jpg', 'video.mp4']);

    final root = entries.singleWhere((e) => e.name == 'root.jpg');
    expect(root.folder, shareName); // 根下文件归属共享目录自身名
    expect(root.size, 2);
    final img = entries.singleWhere((e) => e.name == 'IMG_001.jpg');
    expect(img.folder, 'day1');
  });

  test('目录不存在时跳过；重叠目录去重', () async {
    await put('a.png');
    final entries = await LibraryScanner()
        .scan([p.join(tmp.path, '不存在'), tmp.path, tmp.path]);
    expect(entries.length, 1);
  });
}
