import 'dart:async';
import 'package:flutter/material.dart';

/// 在被动方屏幕弹出配对确认；55 秒无操作自动拒绝。
Future<bool> showPairDialog(GlobalKey<NavigatorState> navigatorKey, String peerName) async {
  final context = navigatorKey.currentContext;
  if (context == null) return false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PairDialog(peerName: peerName),
  );
  return result ?? false;
}

class PairDialog extends StatefulWidget {
  const PairDialog({super.key, required this.peerName});
  final String peerName;

  @override
  State<PairDialog> createState() => _PairDialogState();
}

class _PairDialogState extends State<PairDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 55), () {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('配对请求'),
        content: Text('设备「${widget.peerName}」请求访问你的图片。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('拒绝')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('同意')),
        ],
      );
}
