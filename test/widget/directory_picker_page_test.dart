import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pic_sync/ui/directory_picker_page.dart';

void main() {
  late Directory tempDir;
  late Directory folderA;
  late Directory folderB;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dir_picker_test_');
    folderA = await Directory(p.join(tempDir.path, 'FolderA')).create();
    folderB = await Directory(p.join(tempDir.path, 'FolderB')).create();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('长按文件夹进入多选模式并可全选与提交', (tester) async {
    List<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<List<String>>(
                MaterialPageRoute(
                  builder: (_) => DirectoryPickerPage(
                    rootPath: tempDir.path,
                    allowMultiple: true,
                    lister: (path) async => [folderA, folderB],
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('FolderA'), findsOneWidget);
    expect(find.text('FolderB'), findsOneWidget);
    expect(find.text('选择此文件夹'), findsOneWidget);

    // 长按 FolderA
    await tester.longPress(find.text('FolderA'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 1 个文件夹'), findsOneWidget);
    expect(find.text('确定选择 (1)'), findsOneWidget);

    // 点击 全选 按钮
    await tester.tap(find.byTooltip('全选当前层级'));
    await tester.pumpAndSettle();

    expect(find.text('已选择 2 个文件夹'), findsOneWidget);
    expect(find.text('确定选择 (2)'), findsOneWidget);

    // 点击 确定选择 (2)
    await tester.tap(find.text('确定选择 (2)'));
    await tester.pumpAndSettle();

    expect(result, unorderedEquals([folderA.path, folderB.path]));
  });

  testWidgets('单选模式默认提交当前文件夹路径', (tester) async {
    List<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<List<String>>(
                MaterialPageRoute(
                  builder: (_) => DirectoryPickerPage(
                    rootPath: tempDir.path,
                    allowMultiple: false,
                    lister: (path) async => [folderA, folderB],
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('选择此文件夹'));
    await tester.pumpAndSettle();

    expect(result, equals([tempDir.path]));
  });
}
