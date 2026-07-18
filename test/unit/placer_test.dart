import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/services/placer.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('picsync_place_');
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  Future<String> mkdir(String rel) async {
    final d = Directory(p.join(tmp.path, rel));
    await d.create(recursive: true);
    return p.normalize(d.absolute.path);
  }

  test('命中子目录同名文件夹', () async {
    final share = await mkdir('share1');
    final travel = await mkdir('share1/相册/旅行');
    final index = await buildFolderIndex([share]);
    expect(resolveTargetDir('旅行', index, '/def'), travel);
  });

  test('共享目录本身参与匹配', () async {
    final share = await mkdir('旅行');
    final index = await buildFolderIndex([share]);
    expect(resolveTargetDir('旅行', index, '/def'), share);
  });

  test('多个同名取共享目录顺序第一个', () async {
    final s1 = await mkdir('s1');
    final s2 = await mkdir('s2');
    final inS2 = await mkdir('s2/重复');
    await mkdir('s1/a/重复'); // s1 在列表更靠前，但先按列表顺序：s2 在前时应取 s2 的
    final index = await buildFolderIndex([s2, s1]);
    expect(resolveTargetDir('重复', index, '/def'), inS2);
  });

  test('同一棵树内 BFS：浅层优先于深层', () async {
    final share = await mkdir('share');
    final shallow = await mkdir('share/目标');
    await mkdir('share/a/目标');
    final index = await buildFolderIndex([share]);
    expect(resolveTargetDir('目标', index, '/def'), shallow);
  });

  test('大小写不敏感命中', () async {
    final share = await mkdir('share');
    final dir = await mkdir('share/Photos');
    final index = await buildFolderIndex([share]);
    expect(resolveTargetDir('photos', index, '/def'), dir);
    expect(resolveTargetDir('PHOTOS', index, '/def'), dir);
  });

  test('未命中落默认目录；隐藏目录不参与', () async {
    final share = await mkdir('share');
    await mkdir('share/.git/独特名');
    final index = await buildFolderIndex([share]);
    expect(resolveTargetDir('不存在的名字', index, '/默认'), '/默认');
    expect(resolveTargetDir('独特名', index, '/默认'), '/默认');
  });

  test('最高优先级：peerFolderOverrides 覆盖同名和默认路径且按设备隔离', () async {
    final share = await mkdir('share');
    final samename = await mkdir('share/旅行');
    final index = await buildFolderIndex([share]);
    final customDevA = '/custom/path/deviceA';
    final customDevB = '/custom/path/deviceB';

    final overrides = {
      'devA': {'旅行': customDevA},
      'devB': {'旅行': customDevB},
    };

    // devA 命中了自定义设定的路径（优先于同名的 samename）
    expect(
      resolveTargetDir('旅行', index, '/def', peerDeviceId: 'devA', peerFolderOverrides: overrides),
      customDevA,
    );
    // 大小写不敏感测试
    expect(
      resolveTargetDir('LÜXING', index, '/def', peerDeviceId: 'devA', peerFolderOverrides: overrides),
      '/def',
    );
    expect(
      resolveTargetDir('旅行', index, '/def', peerDeviceId: 'devA', peerFolderOverrides: {'devA': {'旅行': customDevA}}),
      customDevA,
    );
    // devB 命中属于 devB 的专有路径
    expect(
      resolveTargetDir('旅行', index, '/def', peerDeviceId: 'devB', peerFolderOverrides: overrides),
      customDevB,
    );
    // 未设定的 devC 回退到同名匹配
    expect(
      resolveTargetDir('旅行', index, '/def', peerDeviceId: 'devC', peerFolderOverrides: overrides),
      samename,
    );
  });
}
