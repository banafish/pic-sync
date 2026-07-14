import 'dart:async';
import 'package:flutter/material.dart';
import '../models/manifest.dart';
import '../services/sync_engine.dart';
import 'format.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key, required this.engine, required this.files});
  final SyncEngine engine;
  final List<ManifestFile> files;

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  StreamSubscription<SyncProgress>? _sub;
  SyncProgress? _last;
  List<SyncItem>? _results;

  @override
  void initState() {
    super.initState();
    _sub = widget.engine.progress.listen((p) {
      if (mounted) setState(() => _last = p);
    });
    _run();
  }

  Future<void> _run() async {
    final results = await widget.engine.run(widget.files);
    if (mounted) setState(() => _results = results);
  }

  Future<void> _retry() async {
    final all = _results!;
    final failed = all.where((r) => r.status == SyncStatus.failed).toList();
    setState(() => _results = null);
    await widget.engine.retry(failed);
    if (mounted) setState(() => _results = all);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _results != null;
    final results = _results;
    final p = _last;
    final done = results?.where((r) => r.status == SyncStatus.done).length ?? p?.completed ?? 0;
    final failed = results?.where((r) => r.status == SyncStatus.failed).length ?? p?.failed ?? 0;
    final totalBytes = p?.totalBytes ?? 0;
    final receivedBytes = p?.receivedBytes ?? 0;
    return PopScope(
      canPop: finished,
      child: Scaffold(
        appBar: AppBar(
          title: Text(finished ? '同步完成' : '正在同步…'),
          automaticallyImplyLeading: finished,
        ),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              LinearProgressIndicator(
                  value: totalBytes == 0 ? (finished ? 1.0 : null) : receivedBytes / totalBytes),
              const SizedBox(height: 8),
              Text('${formatBytes(receivedBytes)} / ${formatBytes(totalBytes)}'),
              const SizedBox(height: 4),
              Text('成功 $done · 失败 $failed · 共 ${widget.files.length}'),
              if (widget.engine.abortedDiskFull)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('磁盘空间不足，同步已中止',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (!finished && p?.currentName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('正在下载：${p!.currentName}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: results == null
                ? const SizedBox.shrink()
                : ListView(children: [
                    for (final item in results)
                      ListTile(
                        dense: true,
                        leading: _icon(context, item.status),
                        title: Text(item.file.name),
                        subtitle: item.error == null
                            ? null
                            : Text(item.error!, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                  ]),
          ),
        ]),
        bottomNavigationBar: !finished
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    if (failed > 0) ...[
                      Expanded(
                          child: FilledButton(
                              onPressed: _retry, child: Text('重试失败项（$failed）'))),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                        child: FilledButton.tonal(
                            onPressed: () =>
                                Navigator.of(context).popUntil((r) => r.isFirst),
                            child: const Text('完成'))),
                  ]),
                ),
              ),
      ),
    );
  }

  Widget _icon(BuildContext context, SyncStatus s) => switch (s) {
        SyncStatus.pending => const Icon(Icons.schedule),
        SyncStatus.downloading => const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        SyncStatus.done => const Icon(Icons.check_circle, color: Colors.green),
        SyncStatus.skipped => const Icon(Icons.skip_next),
        SyncStatus.failed => Icon(Icons.error, color: Theme.of(context).colorScheme.error),
      };
}
