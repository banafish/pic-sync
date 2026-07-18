import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/manifest.dart';
import '../services/http_client.dart';
import '../services/media_types.dart';
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

  void _showImagePreview(ManifestFile f) {
    if (_data == null) return;
    final client = _data!.client;
    final url = Uri.parse('http://${client.host}:${client.port}/file')
        .replace(queryParameters: {'path': f.path}).toString();
    final headers = client.token != null ? {'X-PicSync-Token': client.token!} : <String, String>{};

    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (ctx) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.black.withAlpha(180),
                  child: Row(
                    children: [
                      const Icon(Icons.image_rounded, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatBytes(f.size),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                        tooltip: '关闭',
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      url,
                      headers: headers,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        final total = loadingProgress.expectedTotalBytes;
                        final loaded = loadingProgress.cumulativeBytesLoaded;
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                value: total != null && total > 0 ? loaded / total : null,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                total != null && total > 0
                                    ? '${formatBytes(loaded)} / ${formatBytes(total)}'
                                    : '正在加载预览…',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54),
                                const SizedBox(height: 12),
                                const Text(
                                  '无法加载图片预览',
                                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$error',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: ListenableBuilder(
                    listenable: m,
                    builder: (_, _) => FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: m.selectedCount == 0 ? null : _startSync,
                      child: Text(
                        '开始同步（${m.selectedCount} 个文件，${formatBytes(m.selectedBytes)}）',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(120),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_outline_rounded, size: 48, color: colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  '没有需要同步的文件',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '对方共 ${_data!.manifest.files.length} 个文件，全部已存在',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
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
          const SliverPadding(padding: EdgeInsets.only(top: 8)),

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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final f = files[index];
                  final isLast = index == files.length - 1;
                  final isSelected = m.isSelected(f);

                  return Material(
                    color: isSelected
                        ? colorScheme.primaryContainer.withAlpha(45)
                        : colorScheme.surface,
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
                    child: InkWell(
                      onTap: () => m.toggleFile(f),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                _buildFileIconAvatar(
                                  f,
                                  colorScheme,
                                  onTapPreview: isImageFile(f.name) ? () => _showImagePreview(f) : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f.name,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
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
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => m.toggleFile(f),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
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

  Widget _buildFileIconAvatar(
    ManifestFile file,
    ColorScheme colorScheme, {
    VoidCallback? onTapPreview,
  }) {
    final name = file.name;
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
    } else if (isImageFile(name)) {
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

    final avatarBox = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: fg),
    );

    if (onTapPreview != null) {
      return Tooltip(
        message: '点击预览图片',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTapPreview,
            borderRadius: BorderRadius.circular(10),
            child: avatarBox,
          ),
        ),
      );
    }

    return avatarBox;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: isFullySelected
            ? colorScheme.primaryContainer.withAlpha(120)
            : colorScheme.surfaceContainerHigh,
        elevation: isPinned ? 3 : 0.5,
        shadowColor: Colors.black.withAlpha(40),
        shape: RoundedRectangleBorder(
          borderRadius: isExpanded
              ? const BorderRadius.vertical(top: Radius.circular(16))
              : BorderRadius.circular(16),
          side: BorderSide(
            color: isFullySelected
                ? colorScheme.primary.withAlpha(80)
                : colorScheme.outlineVariant.withAlpha(60),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  tristate: true,
                  visualDensity: VisualDensity.compact,
                  value: isFullySelected
                      ? true
                      : (selectedCount == 0 ? false : null),
                  onChanged: (_) => onToggleSelect(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isFullySelected
                        ? colorScheme.primary.withAlpha(30)
                        : colorScheme.surface.withAlpha(180),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isExpanded
                        ? Icons.folder_open_rounded
                        : Icons.folder_rounded,
                    color: isFullySelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
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
                          color: isFullySelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '缺 $fileCount / 共 $totalRemoteCount    '),
                            TextSpan(
                              text: '已选 $selectedCount',
                              style: TextStyle(
                                color: isFullySelected
                                    ? colorScheme.primary
                                    : colorScheme.primary.withAlpha(200),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
