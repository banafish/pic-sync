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
    return Scaffold(
      appBar: AppBar(title: const Text('我的共享')),
      body: ListView(children: [
        ListTile(
          title: const Text('设备名'),
          subtitle: Text(s.deviceName),
          trailing: const Icon(Icons.edit),
          onTap: () async {
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
        const Divider(),
        ListTile(
          title: const Text('默认接收目录'),
          subtitle: Text(s.defaultRecvDir.isEmpty ? '未设置（同步前必须设置）' : s.defaultRecvDir),
          trailing: const Icon(Icons.folder_open),
          onTap: () async {
            final path = await effectivePicker.pickDirectory(context);
            if (path != null) await app.setDefaultRecvDir(path);
          },
        ),
        const Divider(),
        ListTile(
          title: Text('共享目录（${s.shareDirs.length}）'),
          subtitle: const Text('这些文件夹里的图片/视频会共享给已配对设备'),
          trailing: IconButton(
            icon: const Icon(Icons.add),
            tooltip: '添加共享目录',
            onPressed: () async {
              final path = await effectivePicker.pickDirectory(context);
              if (path != null) await app.addShareDir(path);
            },
          ),
        ),
        for (final dir in s.shareDirs)
          ListTile(
            leading: const Icon(Icons.folder),
            title: Text(dir),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => app.removeShareDir(dir),
            ),
          ),
      ]),
    );
  }
}
