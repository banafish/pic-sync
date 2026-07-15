import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key, required this.child});
  final Widget child;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!Platform.isAndroid) {
      setState(() => _granted = true);
      return;
    }
    final status = await Permission.manageExternalStorage.status;
    if (mounted) setState(() => _granted = status.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted;
    if (granted == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (granted) return widget.child;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.folder_shared, size: 64),
            const SizedBox(height: 16),
            const Text('需要「所有文件访问」权限',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              '本应用需要读写你选择的图片文件夹，才能在设备间同步图片。\n请在接下来的系统页面中授予「所有文件访问」权限。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await Permission.manageExternalStorage.request();
                await _check();
              },
              child: const Text('去授权'),
            ),
          ]),
        ),
      ),
    );
  }
}
