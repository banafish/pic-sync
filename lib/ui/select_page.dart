import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text('从「${widget.device.name}」同步')),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ]))
          : m == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_status),
                ]))
              : _buildList(m),
      bottomNavigationBar: m == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ListenableBuilder(
                  listenable: m,
                  builder: (_, _) => FilledButton(
                    onPressed: m.selectedCount == 0 ? null : _startSync,
                    child: Text(
                        '开始同步（${m.selectedCount} 个文件，${formatBytes(m.selectedBytes)}）'),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildList(SelectionModel m) {
    if (m.groups.isEmpty) {
      return Center(
          child: Text('没有需要同步的文件\n（对方共 ${_data!.manifest.files.length} 个，全部已存在）',
              textAlign: TextAlign.center));
    }
    return ListenableBuilder(
      listenable: m,
      builder: (_, _) => ListView(children: [
        for (final entry in m.groups.entries)
          ExpansionTile(
            leading: Checkbox(
              tristate: true,
              value: m.folderFullySelected(entry.key)
                  ? true
                  : (m.selectedCountIn(entry.key) == 0 ? false : null),
              onChanged: (_) => m.toggleFolder(entry.key),
            ),
            title: Text(entry.key),
            subtitle: Text('缺 ${entry.value.length} / 共 '
                '${_data!.remotePerFolder[entry.key] ?? entry.value.length}，'
                '已选 ${m.selectedCountIn(entry.key)}'),
            children: [
              for (final f in entry.value)
                CheckboxListTile(
                  dense: true,
                  value: m.isSelected(f),
                  onChanged: (_) => m.toggleFile(f),
                  title: Text(f.name),
                  subtitle: Text(formatBytes(f.size)),
                ),
            ],
          ),
      ]),
    );
  }
}
