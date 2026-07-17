import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class DirectoryPickerPage extends StatefulWidget {
  const DirectoryPickerPage({super.key, required this.rootPath});
  final String rootPath;

  @override
  State<DirectoryPickerPage> createState() => _DirectoryPickerPageState();
}

class _DirectoryPickerPageState extends State<DirectoryPickerPage> {
  late String _current = widget.rootPath;
  List<Directory> _subs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await Directory(_current).list(followLinks: false).toList();
      final subs = list
          .whereType<Directory>()
          .where((d) => !p.basename(d.path).startsWith('.'))
          .toList()
        ..sort((a, b) =>
            p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      setState(() {
        _error = null;
        _subs = subs;
      });
    } on FileSystemException catch (e) {
      setState(() {
        _error = '无法读取该目录：${e.message}';
        _subs = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final atRoot = p.equals(_current, widget.rootPath);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('选择文件夹'),
        leading: BackButton(onPressed: () {
          if (atRoot) {
            Navigator.of(context).pop();
          } else {
            setState(() => _current = p.dirname(_current));
            _load();
          }
        }),
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
                        itemBuilder: (_, i) => Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: Icon(Icons.folder, color: colorScheme.primary),
                            title: Text(
                              p.basename(_subs[i].path),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                            onTap: () {
                              setState(() => _current = _subs[i].path);
                              _load();
                            },
                          ),
                        ),
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
              onPressed: () => Navigator.of(context).pop(_current),
              child: const Text('选择此文件夹', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
