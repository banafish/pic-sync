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
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Icon(Icons.push_pin_outlined, color: colorScheme.onSecondaryContainer),
                  ),
                  title: const Text('特定文件夹保存规则', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('优先将特定设备的远程文件夹保存至指定目录'),
                ),
                if (s.peerFolderOverrides.isEmpty) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '无配置规则（可在同步文件选择页点击文件夹卡片右侧按钮添加）',
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                ] else ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  for (final entry in s.peerFolderOverrides.entries)
                    for (final rule in entry.value.entries)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.folder_special_outlined, color: colorScheme.primary),
                        title: Text(
                          '${s.peerNames[entry.key] ?? entry.key} / ${rule.key}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          '➔ ${rule.value}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: colorScheme.error,
                          tooltip: '删除此规则',
                          onPressed: () => app.removePeerFolderOverride(entry.key, rule.key),
                        ),
                      ),
                ],
              ],
            ),
          ),

          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      final paths = await effectivePicker.pickDirectories(context);
                      for (final path in paths) {
                        await app.addShareDir(path);
                      }
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
