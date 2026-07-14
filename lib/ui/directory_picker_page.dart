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
    return Scaffold(
      appBar: AppBar(
        title: Text(_current, style: const TextStyle(fontSize: 14)),
        leading: BackButton(onPressed: () {
          if (atRoot) {
            Navigator.of(context).pop();
          } else {
            setState(() => _current = p.dirname(_current));
            _load();
          }
        }),
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : ListView.builder(
              itemCount: _subs.length,
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(Icons.folder),
                title: Text(p.basename(_subs[i].path)),
                onTap: () {
                  setState(() => _current = _subs[i].path);
                  _load();
                },
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_current),
            child: const Text('选择此文件夹'),
          ),
        ),
      ),
    );
  }
}
