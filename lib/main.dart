import 'package:flutter/material.dart';

void main() => runApp(const PicSyncApp());

class PicSyncApp extends StatelessWidget {
  const PicSyncApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '图片同步',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(title: const Text('图片同步')),
          body: const Center(child: Text('开发中')),
        ),
      );
}
