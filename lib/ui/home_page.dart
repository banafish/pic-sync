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

    final shareDirCount = app.settings.shareDirs.length;
    final hasDefaultRecv = app.settings.defaultRecvDir.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sync_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Text('图片同步'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShareSettingsPage()),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: Badge(
                isLabelVisible: shareDirCount > 0,
                label: Text('$shareDirCount'),
                backgroundColor: colorScheme.primary,
                child: const Icon(Icons.folder_shared_outlined, size: 20),
              ),
              label: const Text('我的共享', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => app.refreshDiscovery(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
          _LocalDeviceHeroCard(
            deviceName: app.settings.deviceName,
            serverPort: app.serverPort,
            shareDirCount: shareDirCount,
            hasDefaultRecv: hasDefaultRecv,
          ),

          const SizedBox(height: 16),

          if (devices.isEmpty && manualHosts.isEmpty)
            _EmptyDeviceCard(colorScheme: colorScheme, theme: theme),

          if (devices.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.wifi_tethering_rounded, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '已发现网络设备 (${devices.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withAlpha(120),
                          blurRadius: 6,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '实时扫描中',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final d in devices)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openDevice(context, app, d),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primaryContainer,
                                colorScheme.primary.withAlpha(40),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            iconForDevice(d.deviceType),
                            color: colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${d.host}:${d.httpPort}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],

          if (manualHosts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.lan_outlined, size: 20, color: colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    '历史手动设备 (${manualHosts.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            for (final host in manualHosts)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openManual(context, app, host),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withAlpha(150),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lan,
                            color: colorScheme.onSecondaryContainer,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                host,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '点击探测并连接',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          color: colorScheme.error,
                          tooltip: '删除记录',
                          onPressed: () => app.removeManualHost(host),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('添加 IP', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
        onPressed: () => _addManual(context, app),
      ),
    );
  }

  void _openDevice(BuildContext context, AppState app, Device device) {
    if (app.settings.defaultRecvDir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在「我的共享」中设置默认接收目录')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SelectPage(device: device)),
    );
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
          decoration: const InputDecoration(
            hintText: '例如 192.168.1.23 或 192.168.1.23:45655',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (host == null || host.isEmpty) return;
    await app.addManualHost(host);
    try {
      await app.probeManualHost(host);
    } catch (_) {}
  }
}

class _LocalDeviceHeroCard extends StatelessWidget {
  const _LocalDeviceHeroCard({
    required this.deviceName,
    required this.serverPort,
    required this.shareDirCount,
    required this.hasDefaultRecv,
  });

  final String deviceName;
  final int? serverPort;
  final int shareDirCount;
  final bool hasDefaultRecv;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withAlpha(160),
            colorScheme.surfaceContainerHigh.withAlpha(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.primary.withAlpha(35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const _RadarPulseAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '本机设备在线 / 局域网广播中',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        deviceName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (serverPort != null)
                        Text(
                          'HTTP 服务端口：$serverPort',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusChip(
                  icon: Icons.folder_open_rounded,
                  label: '$shareDirCount 个共享目录',
                  isOk: shareDirCount > 0,
                ),
                const SizedBox(width: 10),
                _StatusChip(
                  icon: Icons.download_rounded,
                  label: hasDefaultRecv ? '接收路径已设' : '未设置接收路径',
                  isOk: hasDefaultRecv,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.isOk,
  });

  final IconData icon;
  final String label;
  final bool isOk;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface.withAlpha(200),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOk ? colorScheme.primary.withAlpha(30) : colorScheme.error.withAlpha(40),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isOk ? colorScheme.primary : colorScheme.error,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOk ? colorScheme.onSurface : colorScheme.error,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPulseAvatar extends StatefulWidget {
  const _RadarPulseAvatar();

  @override
  State<_RadarPulseAvatar> createState() => _RadarPulseAvatarState();
}

class _RadarPulseAvatarState extends State<_RadarPulseAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.3);
        final opacity = (1.0 - _controller.value).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withAlpha((opacity * 60).round()),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withAlpha(80),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          iconForDevice(defaultDeviceType()),
          color: colorScheme.onPrimary,
          size: 28,
        ),
      ),
    );
  }
}

class _EmptyDeviceCard extends StatelessWidget {
  const _EmptyDeviceCard({
    required this.colorScheme,
    required this.theme,
  });

  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.radar_rounded,
                size: 38,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '未发现设备，自动搜索中...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GuideStepRow(
                    icon: Icons.wifi_rounded,
                    text: '确认对方设备处于相同 Wi-Fi 并已打开 PicSync',
                  ),
                  const SizedBox(height: 8),
                  _GuideStepRow(
                    icon: Icons.folder_shared_outlined,
                    text: '首次使用请点击右上角「我的共享」添加共享文件夹',
                  ),
                  const SizedBox(height: 8),
                  _GuideStepRow(
                    icon: Icons.add_circle_outline_rounded,
                    text: '若未能自动搜索到，可用右下角「添加 IP」手动探测',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStepRow extends StatelessWidget {
  const _GuideStepRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

IconData iconForDevice(String? deviceType) {
  if (deviceType == 'desktop' || deviceType == 'pc') {
    return Icons.desktop_windows_rounded;
  }
  return Icons.smartphone_rounded;
}
