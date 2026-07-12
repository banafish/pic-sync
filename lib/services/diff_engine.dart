import '../models/file_entry.dart';
import '../models/manifest.dart';

class DiffResult {
  final List<ManifestFile> missing;
  final Map<String, List<ManifestFile>> byFolder;
  const DiffResult({required this.missing, required this.byFolder});
}

/// 文件名（含扩展名）全局比对，不区分大小写；
/// 远端文件名不在本机集合中 => 缺失。
DiffResult computeMissing(List<ManifestFile> remoteFiles, Iterable<FileEntry> localFiles) {
  final localNames = localFiles.map((e) => e.name.toLowerCase()).toSet();
  final missing = <ManifestFile>[];
  final byFolder = <String, List<ManifestFile>>{};
  for (final f in remoteFiles) {
    if (localNames.contains(f.name.toLowerCase())) continue;
    missing.add(f);
    byFolder.putIfAbsent(f.folder, () => []).add(f);
  }
  return DiffResult(missing: missing, byFolder: byFolder);
}
