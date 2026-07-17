import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'directory_picker_page.dart';

abstract class DirectoryPicker {
  Future<String?> pickDirectory(BuildContext context);
  Future<List<String>> pickDirectories(BuildContext context) async {
    final res = await pickDirectory(context);
    return res != null ? [res] : [];
  }
}

class PlatformDirectoryPicker implements DirectoryPicker {
  @override
  Future<String?> pickDirectory(BuildContext context) async {
    if (Platform.isAndroid) {
      final res = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (_) => const DirectoryPickerPage(
            rootPath: '/storage/emulated/0',
            allowMultiple: false,
          ),
        ),
      );
      if (res is List<String>) return res.firstOrNull;
      if (res is String) return res;
      return null;
    }
    return FilePicker.getDirectoryPath(dialogTitle: '选择文件夹');
  }

  @override
  Future<List<String>> pickDirectories(BuildContext context) async {
    if (Platform.isAndroid) {
      final res = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (_) => const DirectoryPickerPage(
            rootPath: '/storage/emulated/0',
            allowMultiple: true,
          ),
        ),
      );
      if (res is List<String>) return res;
      if (res is String) return [res];
      return [];
    }
    final res = await FilePicker.getDirectoryPath(dialogTitle: '选择文件夹');
    return res != null ? [res] : [];
  }
}
