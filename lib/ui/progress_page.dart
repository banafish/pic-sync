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
  final Set<String> _collapsedFolders = {};

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
                  : _buildGroupedList(results),
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

  Widget _buildGroupedList(List<SyncItem> results) {
    final groups = <String, List<SyncItem>>{};
    for (final item in results) {
      groups.putIfAbsent(item.file.folder, () => []).add(item);
    }

    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        const SliverPadding(padding: EdgeInsets.only(top: 8)),
        for (final entry in groups.entries)
          _buildFolderSliverGroup(theme, entry.key, entry.value),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget _buildFolderSliverGroup(ThemeData theme, String folderName, List<SyncItem> items) {
    final isExpanded = !_collapsedFolders.contains(folderName);
    final doneCount = items.where((i) => i.status == SyncStatus.done).length;
    final failedCount = items.where((i) => i.status == SyncStatus.failed).length;
    final colorScheme = theme.colorScheme;

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _ProgressFolderHeaderDelegate(
            folderName: folderName,
            totalCount: items.length,
            doneCount: doneCount,
            failedCount: failedCount,
            isExpanded: isExpanded,
            onToggleExpand: () {
              setState(() {
                if (isExpanded) {
                  _collapsedFolders.add(folderName);
                } else {
                  _collapsedFolders.remove(folderName);
                }
              });
            },
            theme: theme,
          ),
        ),
        if (isExpanded)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = items[index];
                  final isLast = index == items.length - 1;
                  return _buildFileTile(context, item, isLast, colorScheme);
                },
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileTile(BuildContext context, SyncItem item, bool isLast, ColorScheme colorScheme) {
    final f = item.file;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        side: BorderSide(
          color: colorScheme.outlineVariant.withAlpha(50),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _buildFileIconAvatar(f.name, colorScheme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (item.error != null)
                        Text(
                          item.error!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colorScheme.error, fontSize: 12),
                        )
                      else
                        Text(
                          formatBytes(f.size),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _icon(context, item.status),
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              indent: 56,
              endIndent: 12,
              color: colorScheme.outlineVariant.withAlpha(40),
            ),
        ],
      ),
    );
  }

  Widget _buildFileIconAvatar(String name, ColorScheme colorScheme) {
    final lower = name.toLowerCase();
    IconData icon;
    Color bg;
    Color fg;

    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi')) {
      icon = Icons.movie_rounded;
      bg = Colors.purple.withAlpha(25);
      fg = Colors.purple;
    } else if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic')) {
      icon = Icons.image_rounded;
      bg = colorScheme.primary.withAlpha(25);
      fg = colorScheme.primary;
    } else if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.aac')) {
      icon = Icons.audiotrack_rounded;
      bg = Colors.teal.withAlpha(25);
      fg = Colors.teal;
    } else {
      icon = Icons.insert_drive_file_rounded;
      bg = Colors.orange.withAlpha(25);
      fg = Colors.orange;
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: fg),
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

class _ProgressFolderHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ProgressFolderHeaderDelegate({
    required this.folderName,
    required this.totalCount,
    required this.doneCount,
    required this.failedCount,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.theme,
  });

  final String folderName;
  final int totalCount;
  final int doneCount;
  final int failedCount;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ThemeData theme;

  @override
  double get minExtent => 64.0;

  @override
  double get maxExtent => 64.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colorScheme = theme.colorScheme;
    final isPinned = overlapsContent || shrinkOffset > 0;
    final hasFailed = failedCount > 0;

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: hasFailed
            ? colorScheme.errorContainer.withAlpha(80)
            : colorScheme.surfaceContainerHigh,
        elevation: isPinned ? 3 : 0.5,
        shadowColor: Colors.black.withAlpha(40),
        shape: RoundedRectangleBorder(
          borderRadius: isExpanded
              ? const BorderRadius.vertical(top: Radius.circular(16))
              : BorderRadius.circular(16),
          side: BorderSide(
            color: hasFailed
                ? colorScheme.error.withAlpha(80)
                : colorScheme.outlineVariant.withAlpha(60),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: hasFailed
                        ? colorScheme.error.withAlpha(25)
                        : colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isExpanded
                        ? Icons.folder_open_rounded
                        : Icons.folder_rounded,
                    color: hasFailed
                        ? colorScheme.error
                        : colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '已完成 $doneCount / 共 $totalCount'),
                            if (hasFailed) ...[
                              const TextSpan(text: '  ·  '),
                              TextSpan(
                                text: '$failedCount 项失败',
                                style: TextStyle(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  onPressed: onToggleExpand,
                  tooltip: isExpanded ? '收起' : '展开',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProgressFolderHeaderDelegate oldDelegate) {
    return oldDelegate.folderName != folderName ||
        oldDelegate.totalCount != totalCount ||
        oldDelegate.doneCount != doneCount ||
        oldDelegate.failedCount != failedCount ||
        oldDelegate.isExpanded != isExpanded ||
        oldDelegate.theme != theme;
  }
}

