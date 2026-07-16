import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/manifest.dart';
import '../services/http_client.dart';
import '../services/sync_engine.dart';
import 'app_state.dart';
import 'format.dart';
import 'progress_page.dart';
import 'select_loader.dart';
import 'selection_model.dart';

class SelectPage extends StatefulWidget {
  const SelectPage({super.key, required this.device, this.loader});
  final Device device;
  final SelectLoader? loader;

  @override
  State<SelectPage> createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> {
  SelectLoadResult? _data;
  SelectionModel? _model;
  String _status = '正在连接…';
  String? _error;
  final Set<String> _expandedFolders = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _data = null;
      _model = null;
      _expandedFolders.clear();
    });
    final app = context.read<AppState>();
    try {
      final data = await (widget.loader ?? SelectLoader()).load(app, widget.device,
          onStatus: (s) {
        if (mounted) setState(() => _status = s);
      });
      if (!mounted) return;
      setState(() {
        _data = data;
        _model = SelectionModel(data.diff);
      });
    } on PairRejected {
      if (mounted) setState(() => _error = '对方拒绝了配对请求');
    } catch (e) {
      if (mounted) setState(() => _error = '连接失败：$e');
    }
  }

  void _startSync() {
    final app = context.read<AppState>();
    final engine = SyncEngine(
      client: _data!.client,
      shareDirs: List.of(app.settings.shareDirs),
      defaultRecvDir: app.settings.defaultRecvDir,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ProgressPage(engine: engine, files: _model!.selectedFiles)));
  }

  @override
  Widget build(BuildContext context) {
    final m = _model;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('从「${widget.device.name}」同步')),
      body: _error != null
          ? Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: colorScheme.error),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : m == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : _buildList(m),
      bottomNavigationBar: m == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ListenableBuilder(
                    listenable: m,
                    builder: (_, _) => FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: m.selectedCount == 0 ? null : _startSync,
                      child: Text(
                        '开始同步（${m.selectedCount} 个文件，${formatBytes(m.selectedBytes)}）',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildList(SelectionModel m) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (m.groups.isEmpty) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 56, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  '没有需要同步的文件\n（对方共 ${_data!.manifest.files.length} 个，全部已存在）',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: m,
      builder: (_, _) => CustomScrollView(
        slivers: [
          // Summary Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Card(
                color: colorScheme.secondaryContainer.withAlpha(100),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.folder_copy_outlined, color: colorScheme.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '准备从「${widget.device.name}」选择要同步的项目',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          for (final entry in m.groups.entries)
            _buildFolderSliverGroup(m, entry.key, entry.value),

          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Widget _buildFolderSliverGroup(
    SelectionModel m,
    String folderName,
    List<ManifestFile> files,
  ) {
    final isExpanded = _expandedFolders.contains(folderName);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _FolderHeaderDelegate(
            folderName: folderName,
            fileCount: files.length,
            totalRemoteCount: _data!.remotePerFolder[folderName] ?? files.length,
            selectedCount: m.selectedCountIn(folderName),
            isFullySelected: m.folderFullySelected(folderName),
            isExpanded: isExpanded,
            onToggleSelect: () => m.toggleFolder(folderName),
            onToggleExpand: () {
              setState(() {
                if (isExpanded) {
                  _expandedFolders.remove(folderName);
                } else {
                  _expandedFolders.add(folderName);
                }
              });
            },
            theme: theme,
          ),
        ),
        if (isExpanded)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final f = files[index];
                  final isLast = index == files.length - 1;
                  return Material(
                    color: colorScheme.surface,
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: isLast
                          ? const BorderRadius.vertical(bottom: Radius.circular(12))
                          : BorderRadius.zero,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CheckboxListTile(
                          dense: true,
                          secondary: Icon(
                            _getFileIcon(f.name),
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          value: m.isSelected(f),
                          onChanged: (_) => m.toggleFile(f),
                          title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(formatBytes(f.size)),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: colorScheme.outlineVariant.withAlpha(80),
                          ),
                      ],
                    ),
                  );
                },
                childCount: files.length,
              ),
            ),
          ),
      ],
    );
  }

  IconData _getFileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.mkv') || lower.endsWith('.avi')) {
      return Icons.video_file_outlined;
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.gif') || lower.endsWith('.webp') || lower.endsWith('.heic')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }
}

class _FolderHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FolderHeaderDelegate({
    required this.folderName,
    required this.fileCount,
    required this.totalRemoteCount,
    required this.selectedCount,
    required this.isFullySelected,
    required this.isExpanded,
    required this.onToggleSelect,
    required this.onToggleExpand,
    required this.theme,
  });

  final String folderName;
  final int fileCount;
  final int totalRemoteCount;
  final int selectedCount;
  final bool isFullySelected;
  final bool isExpanded;
  final VoidCallback onToggleSelect;
  final VoidCallback onToggleExpand;
  final ThemeData theme;

  @override
  double get minExtent => 68.0;

  @override
  double get maxExtent => 68.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colorScheme = theme.colorScheme;
    final isPinned = overlapsContent || shrinkOffset > 0;

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        elevation: isPinned ? 3 : 1,
        shadowColor: Colors.black.withAlpha(50),
        shape: RoundedRectangleBorder(
          borderRadius: isExpanded
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Checkbox(
                  tristate: true,
                  value: isFullySelected
                      ? true
                      : (selectedCount == 0 ? false : null),
                  onChanged: (_) => onToggleSelect(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folderName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '缺 $fileCount / 共 $totalRemoteCount，已选 $selectedCount',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
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
  bool shouldRebuild(covariant _FolderHeaderDelegate oldDelegate) {
    return oldDelegate.folderName != folderName ||
        oldDelegate.fileCount != fileCount ||
        oldDelegate.totalRemoteCount != totalRemoteCount ||
        oldDelegate.selectedCount != selectedCount ||
        oldDelegate.isFullySelected != isFullySelected ||
        oldDelegate.isExpanded != isExpanded ||
        oldDelegate.theme != theme;
  }
}
