import 'dart:collection';
import 'dart:io';
import 'package:path/path.dart' as p;

/// 遍历共享目录（按列表顺序；每棵树 BFS，同层按名称排序；候选含共享目录本身），
/// 建立 小写文件夹名 -> 目录绝对路径 索引，先到先得。隐藏目录（. 开头）跳过。
Future<Map<String, String>> buildFolderIndex(List<String> shareDirs) async {
  final index = <String, String>{};
  for (final dirPath in shareDirs) {
    final root = Directory(dirPath);
    if (!await root.exists()) continue;
    final queue = Queue<Directory>()..add(root);
    while (queue.isNotEmpty) {
      final dir = queue.removeFirst();
      index.putIfAbsent(
          p.basename(dir.path).toLowerCase(), () => p.normalize(dir.absolute.path));
      List<Directory> subs;
      try {
        subs = (await dir.list(followLinks: false).toList())
            .whereType<Directory>()
            .where((d) => !p.basename(d.path).startsWith('.'))
            .toList();
      } on FileSystemException {
        continue;
      }
      subs.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
      queue.addAll(subs);
    }
  }
  return index;
}

/// 命中指定设备级映射目录（不区分大小写，最高优先级），次之命中同名目录，否则返回默认接收目录。
String resolveTargetDir(
  String folderName,
  Map<String, String> folderIndex,
  String defaultRecvDir, {
  String? peerDeviceId,
  Map<String, Map<String, String>>? peerFolderOverrides,
}) {
  final folderKey = folderName.toLowerCase();
  if (peerDeviceId != null && peerFolderOverrides != null) {
    final overrides = peerFolderOverrides[peerDeviceId];
    if (overrides != null && overrides.containsKey(folderKey)) {
      final overridePath = overrides[folderKey];
      if (overridePath != null && overridePath.isNotEmpty) {
        return overridePath;
      }
    }
  }
  return folderIndex[folderKey] ?? defaultRecvDir;
}
