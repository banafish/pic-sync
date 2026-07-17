import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

typedef DirectoryLister = Future<List<Directory>> Function(String path);

class DirectoryPickerPage extends StatefulWidget {
  const DirectoryPickerPage({
    super.key,
    required this.rootPath,
    this.allowMultiple = true,
    this.lister,
  });
  final String rootPath;
  final bool allowMultiple;
  final DirectoryLister? lister;

  @override
  State<DirectoryPickerPage> createState() => _DirectoryPickerPageState();
}

class _DirectoryPickerPageState extends State<DirectoryPickerPage> {
  late String _current = widget.rootPath;
  List<Directory> _subs = [];
  String? _error;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Directory> subs;
      if (widget.lister != null) {
        subs = await widget.lister!(_current);
      } else {
        final list = await Directory(_current).list(followLinks: false).toList();
        subs = list
            .whereType<Directory>()
            .where((d) => !p.basename(d.path).startsWith('.'))
            .toList()
          ..sort((a, b) =>
              p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      }
      if (!mounted) return;
      setState(() {
        _error = null;
        _subs = subs;
      });
    } on FileSystemException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '无法读取该目录：${e.message}';
        _subs = [];
      });
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final atRoot = p.equals(_current, widget.rootPath);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMultiSelectMode = _selectedPaths.isNotEmpty;
    final allSubsSelected =
        _subs.isNotEmpty && _subs.every((d) => _selectedPaths.contains(d.path));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMultiSelectMode ? '已选择 ${_selectedPaths.length} 个文件夹' : '选择文件夹',
        ),
        leading: isMultiSelectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: '取消选择',
                onPressed: () => setState(() => _selectedPaths.clear()),
              )
            : BackButton(onPressed: () {
                if (atRoot) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _current = p.dirname(_current));
                  _load();
                }
              }),
        actions: [
          if (widget.allowMultiple && _subs.isNotEmpty)
            IconButton(
              icon: Icon(allSubsSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
              tooltip: allSubsSelected ? '取消全选当前层级' : '全选当前层级',
              onPressed: () {
                setState(() {
                  if (allSubsSelected) {
                    for (final d in _subs) {
                      _selectedPaths.remove(d.path);
                    }
                  } else {
                    for (final d in _subs) {
                      _selectedPaths.add(d.path);
                    }
                  }
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_special_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _current,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  )
                : _subs.isEmpty
                    ? Center(
                        child: Text(
                          '此目录下无子文件夹',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _subs.length,
                        itemBuilder: (_, i) {
                          final dir = _subs[i];
                          final isSelected = _selectedPaths.contains(dir.path);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: isSelected
                                ? colorScheme.primaryContainer.withAlpha(80)
                                : null,
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              selected: isSelected,
                              leading: isMultiSelectMode
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleSelection(dir.path),
                                    )
                                  : Icon(Icons.folder, color: colorScheme.primary),
                              title: Text(
                                p.basename(dir.path),
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.chevron_right),
                                color: colorScheme.onSurfaceVariant,
                                tooltip: '进入子文件夹',
                                onPressed: () {
                                  setState(() => _current = dir.path);
                                  _load();
                                },
                              ),
                              onTap: () {
                                if (isMultiSelectMode) {
                                  _toggleSelection(dir.path);
                                } else {
                                  setState(() => _current = dir.path);
                                  _load();
                                }
                              },
                              onLongPress: widget.allowMultiple
                                  ? () => _toggleSelection(dir.path)
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                if (isMultiSelectMode) {
                  Navigator.of(context).pop(_selectedPaths.toList());
                } else {
                  Navigator.of(context).pop([_current]);
                }
              },
              child: Text(
                isMultiSelectMode
                    ? '确定选择 (${_selectedPaths.length})'
                    : '选择此文件夹',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
