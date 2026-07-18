import 'dart:async';
import 'dart:io';
import '../models/manifest.dart';
import 'http_client.dart';
import 'placer.dart';

enum SyncStatus { pending, downloading, done, skipped, failed }

class SyncItem {
  SyncItem(this.file);
  final ManifestFile file;
  SyncStatus status = SyncStatus.pending;
  String? error;
}

class SyncProgress {
  const SyncProgress({
    required this.total,
    required this.completed,
    required this.failed,
    required this.totalBytes,
    required this.receivedBytes,
    this.currentName,
  });
  final int total;
  final int completed;
  final int failed;
  final int totalBytes;
  final int receivedBytes;
  final String? currentName;
}

bool _isDiskFull(Object e) =>
    e is FileSystemException &&
    (e.osError?.errorCode == 28 || e.osError?.errorCode == 112); // ENOSPC / ERROR_DISK_FULL

class SyncEngine {
  SyncEngine({
    required this.client,
    required this.shareDirs,
    required this.defaultRecvDir,
    this.peerDeviceId,
    this.peerFolderOverrides,
    this.concurrency = 3,
  });

  final PeerClient client;
  final List<String> shareDirs;
  final String defaultRecvDir;
  final String? peerDeviceId;
  final Map<String, Map<String, String>>? peerFolderOverrides;
  final int concurrency;

  final StreamController<SyncProgress> _progress = StreamController.broadcast();
  Stream<SyncProgress> get progress => _progress.stream;

  bool abortedDiskFull = false;

  int _completed = 0;
  int _failed = 0;
  int _total = 0;
  int _totalBytes = 0;
  int _bytesFinished = 0;
  final Map<SyncItem, int> _inflight = {};
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  Future<List<SyncItem>> run(List<ManifestFile> files) async {
    final items = files.map(SyncItem.new).toList();
    await _process(items);
    return items;
  }

  Future<List<SyncItem>> retry(List<SyncItem> failedItems) async {
    for (final it in failedItems) {
      it.status = SyncStatus.pending;
      it.error = null;
    }
    await _process(failedItems);
    return failedItems;
  }

  Future<void> _process(List<SyncItem> items) async {
    _total = items.length;
    _completed = 0;
    _failed = 0;
    _totalBytes = items.fold(0, (s, i) => s + i.file.size);
    _bytesFinished = 0;
    _inflight.clear();
    abortedDiskFull = false;
    final folderIndex = await buildFolderIndex(shareDirs);
    final queue = List<SyncItem>.from(items);
    _emit(null, force: true);

    Future<void> worker() async {
      while (queue.isNotEmpty && !abortedDiskFull) {
        final item = queue.removeAt(0);
        item.status = SyncStatus.downloading;
        _emit(item.file.name, force: true);
        final targetDir = resolveTargetDir(
          item.file.folder,
          folderIndex,
          defaultRecvDir,
          peerDeviceId: peerDeviceId,
          peerFolderOverrides: peerFolderOverrides,
        );
        try {
          await client.downloadFile(
            remotePath: item.file.path,
            targetDir: targetDir,
            fileName: item.file.name,
            expectedSize: item.file.size,
            onProgress: (received) {
              _inflight[item] = received;
              _emit(item.file.name);
            },
          );
          item.status = SyncStatus.done;
          _completed++;
        } catch (e) {
          item.status = SyncStatus.failed;
          item.error = e is DownloadError ? e.message : '$e';
          _failed++;
          if (_isDiskFull(e)) {
            item.error = '磁盘空间不足';
            abortedDiskFull = true; // 停止取剩余队列（规格 §7）
          }
        }
        _inflight.remove(item);
        if (item.status == SyncStatus.done) _bytesFinished += item.file.size;
        _emit(null, force: true);
      }
    }

    await Future.wait(List.generate(concurrency < 1 ? 1 : concurrency, (_) => worker()));
    _emit(null, force: true);
  }

  /// 进度事件节流：非强制时至多每 100ms 一条，避免 UI 重建风暴。
  void _emit(String? currentName, {bool force = false}) {
    if (_progress.isClosed) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastEmit).inMilliseconds < 100) return;
    _lastEmit = now;
    final inflightSum = _inflight.values.fold(0, (a, b) => a + b);
    _progress.add(SyncProgress(
      total: _total,
      completed: _completed,
      failed: _failed,
      totalBytes: _totalBytes,
      receivedBytes: _bytesFinished + inflightSum,
      currentName: currentName,
    ));
  }

  void dispose() => _progress.close();
}
