import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'directory_picker.dart';

class ShareSettingsPage extends StatelessWidget {
  const ShareSettingsPage({super.key, this.picker});
  final DirectoryPicker? picker;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;
    final effectivePicker = picker ?? PlatformDirectoryPicker();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('我的共享')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                child: Icon(Icons.badge_outlined, color: colorScheme.onSecondaryContainer),
              ),
              title: const Text('设备名', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s.deviceName),
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.edit),
                tooltip: '修改设备名',
                onPressed: () async {
                  final controller = TextEditingController(text: s.deviceName);
                  final name = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('修改设备名'),
                      content: TextField(controller: controller, autofocus: true),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, controller.text),
                            child: const Text('确定')),
                      ],
                    ),
                  );
                  if (name != null) await app.setDeviceName(name);
                },
              ),
            ),
          ),

          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                backgroundColor: s.defaultRecvDir.isEmpty
                    ? colorScheme.errorContainer
                    : colorScheme.secondaryContainer,
                child: Icon(
                  Icons.folder_open,
                  color: s.defaultRecvDir.isEmpty
                      ? colorScheme.onErrorContainer
                      : colorScheme.onSecondaryContainer,
                ),
              ),
              title: const Text('默认接收目录', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                s.defaultRecvDir.isEmpty ? '未设置（同步前必须设置）' : s.defaultRecvDir,
                style: TextStyle(
                  color: s.defaultRecvDir.isEmpty ? colorScheme.error : colorScheme.onSurfaceVariant,
                  fontWeight: s.defaultRecvDir.isEmpty ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
              onTap: () async {
                final path = await effectivePicker.pickDirectory(context);
                if (path != null) await app.setDefaultRecvDir(path);
              },
            ),
          ),

          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text('共享目录（${s.shareDirs.length}）',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('这些文件夹里的图片/视频会共享给已配对设备'),
                  trailing: IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    tooltip: '添加共享目录',
                    onPressed: () async {
                      final path = await effectivePicker.pickDirectory(context);
                      if (path != null) await app.addShareDir(path);
                    },
                  ),
                ),
                if (s.shareDirs.isNotEmpty) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  for (final dir in s.shareDirs)
                    ListTile(
                      leading: Icon(Icons.folder, color: colorScheme.primary),
                      title: Text(dir, style: const TextStyle(fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: colorScheme.error,
                        onPressed: () => app.removeShareDir(dir),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
