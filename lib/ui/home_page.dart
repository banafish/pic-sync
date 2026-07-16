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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('图片同步'),
        actions: [
          IconButton.filledTonal(
            icon: const Icon(Icons.folder_shared_outlined),
            tooltip: '我的共享',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ShareSettingsPage())),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (app.startupError != null)
            Card(
              color: colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        app.startupError!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 本机状态 Hero Banner
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            color: colorScheme.primaryContainer.withAlpha(120),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: colorScheme.primary.withAlpha(40),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smartphone,
                      color: colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '本机设备在线',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '本机：${app.settings.deviceName}'
                          '${app.serverPort != null ? '（端口 ${app.serverPort}）' : ''}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (devices.isEmpty && manualHosts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.devices_other_rounded,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '未发现设备。\n请确认对方设备也打开了本应用，\n或用右下角按钮手动添加对方 IP。\n\n首次使用请先到右上角「我的共享」\n添加共享目录并设置默认接收目录。',
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

          if (devices.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
              child: Text(
                '已发现网络设备 (${devices.length})',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final d in devices)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      d.manual ? Icons.lan_outlined : Icons.devices_rounded,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    d.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${d.host}:${d.httpPort}',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: () => _openDevice(context, app, d),
                ),
              ),
          ],

          if (manualHosts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
              child: Text(
                '手动添加设备 (${manualHosts.length})',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final host in manualHosts)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.lan,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(
                    host,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: const Text('手动添加 IP'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: colorScheme.error,
                    onPressed: () => app.removeManualHost(host),
                  ),
                  onTap: () => _openManual(context, app, host),
                ),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加 IP'),
        elevation: 3,
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
