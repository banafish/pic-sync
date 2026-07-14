import 'package:flutter/material.dart';
import '../models/manifest.dart';
import '../services/sync_engine.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key, required this.engine, required this.files});
  final SyncEngine engine;
  final List<ManifestFile> files;

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('同步中')));
}
