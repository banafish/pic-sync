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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasError = failed > 0 || widget.engine.abortedDiskFull;

    return PopScope(
      canPop: finished,
      child: Scaffold(
        appBar: AppBar(
          title: Text(finished ? (hasError ? '同步有失败' : '同步完成') : '正在同步…'),
          automaticallyImplyLeading: finished,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: totalBytes == 0 ? (finished ? 1.0 : null) : receivedBytes / totalBytes,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${formatBytes(receivedBytes)} / ${formatBytes(totalBytes)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: !finished
                                ? colorScheme.surfaceContainerHigh
                                : hasError
                                    ? colorScheme.errorContainer
                                    : colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            !finished
                                ? '传输中'
                                : widget.engine.abortedDiskFull
                                    ? '已中止'
                                    : hasError
                                        ? '有失败'
                                        : '已传完',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !finished
                                  ? colorScheme.onSurfaceVariant
                                  : hasError
                                      ? colorScheme.onErrorContainer
                                      : colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '成功 $done · 失败 $failed · 共 ${widget.files.length}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    if (widget.engine.abortedDiskFull)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '磁盘空间不足，同步已中止',
                          style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (!finished && p?.currentName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '正在下载：${p!.currentName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: results == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        for (final item in results)
                          Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              dense: true,
                              leading: _icon(context, item.status),
                              title: Text(item.file.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: item.error == null
                                  ? null
                                  : Text(
                                      item.error!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: colorScheme.error),
                                    ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
        bottomNavigationBar: !finished
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (failed > 0) ...[
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _retry,
                            child: Text('重试失败项（$failed）'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                          child: const Text('完成'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _icon(BuildContext context, SyncStatus s) => switch (s) {
        SyncStatus.pending => Icon(Icons.schedule, color: Theme.of(context).colorScheme.outline),
        SyncStatus.downloading => const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        SyncStatus.done => const Icon(Icons.check_circle_rounded, color: Colors.green),
        SyncStatus.skipped => Icon(Icons.skip_next_rounded, color: Theme.of(context).colorScheme.outline),
        SyncStatus.failed => Icon(Icons.error_rounded, color: Theme.of(context).colorScheme.error),
      };
}
