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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.phonelink_ring_rounded,
          size: 32,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: const Text('配对请求', textAlign: TextAlign.center),
      content: Text(
        '设备「${widget.peerName}」请求访问你的图片。',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('拒绝'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('同意'),
        ),
      ],
    );
  }
}
