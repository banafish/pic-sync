import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/file_entry.dart';
import 'media_types.dart';

class LibraryScanner {
  Future<List<FileEntry>> scan(List<String> shareDirs) async {
    final result = <FileEntry>[];
    final seen = <String>{};
    for (final dirPath in shareDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      await _scanDir(dir, result, seen);
    }
    return result;
  }

  Future<void> _scanDir(Directory dir, List<FileEntry> out, Set<String> seen) async {
    final List<FileSystemEntity> children;
    try {
      children = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      return; // 无权限等，跳过该目录
    }
    for (final entity in children) {
      final base = p.basename(entity.path);
      if (base.startsWith('.')) continue; // 隐藏文件/目录
      if (entity is Directory) {
        await _scanDir(entity, out, seen);
      } else if (entity is File) {
        if (base.toLowerCase().endsWith('.part')) continue;
        if (!isMediaFile(base)) continue;
        final abs = p.normalize(entity.absolute.path);
        if (!seen.add(abs)) continue; // 共享目录重叠时去重
        final int size;
        try {
          size = await entity.length();
        } on FileSystemException {
          continue;
        }
        out.add(FileEntry(
          name: base,
          size: size,
          folder: p.basename(p.dirname(abs)),
          absPath: abs,
        ));
      }
    }
  }
}
