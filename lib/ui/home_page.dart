import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import 'app_state.dart';
import 'select_page.dart';
import 'share_settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final devices = app.devices;
    final manualHosts = app.settings.manualHosts;
    return Scaffold(
      appBar: AppBar(title: const Text('图片同步'), actions: [
        IconButton(
          icon: const Icon(Icons.folder_shared),
          tooltip: '我的共享',
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ShareSettingsPage())),
        ),
      ]),
      body: ListView(children: [
        if (app.startupError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(app.startupError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('本机：${app.settings.deviceName}'
              '${app.serverPort != null ? '（端口 ${app.serverPort}）' : ''}'),
        ),
        const Divider(height: 1),
        if (devices.isEmpty && manualHosts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: Text(
                    '未发现设备。\n请确认对方设备也打开了本应用，\n或用右下角按钮手动添加对方 IP。\n\n首次使用请先到右上角「我的共享」\n添加共享目录并设置默认接收目录。',
                    textAlign: TextAlign.center)),
          ),
        for (final d in devices)
          ListTile(
            leading: Icon(d.manual ? Icons.lan : Icons.devices),
            title: Text(d.name),
            subtitle: Text('${d.host}:${d.httpPort}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDevice(context, app, d),
          ),
        for (final host in manualHosts)
          ListTile(
            leading: const Icon(Icons.lan),
            title: Text(host),
            subtitle: const Text('手动添加'),
            trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => app.removeManualHost(host)),
            onTap: () => _openManual(context, app, host),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('添加 IP'),
        onPressed: () => _addManual(context, app),
      ),
    );
  }

  void _openDevice(BuildContext context, AppState app, Device device) {
    if (app.settings.defaultRecvDir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在「我的共享」中设置默认接收目录')));
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SelectPage(device: device)));
  }

  Future<void> _openManual(BuildContext context, AppState app, String host) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final device = await app.probeManualHost(host);
      if (!context.mounted) return;
      _openDevice(context, app, device);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('连接失败：$e')));
    }
  }

  Future<void> _addManual(BuildContext context, AppState app) async {
    final controller = TextEditingController();
    final host = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加设备 IP'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: '例如 192.168.1.23 或 192.168.1.23:45656'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('添加')),
        ],
      ),
    );
    if (host == null || host.isEmpty) return;
    await app.addManualHost(host);
  }
}
