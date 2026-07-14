import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'directory_picker_page.dart';

abstract class DirectoryPicker {
  Future<String?> pickDirectory(BuildContext context);
}

class PlatformDirectoryPicker implements DirectoryPicker {
  @override
  Future<String?> pickDirectory(BuildContext context) async {
    if (Platform.isAndroid) {
      return Navigator.of(context).push<String>(MaterialPageRoute(
          builder: (_) => const DirectoryPickerPage(rootPath: '/storage/emulated/0')));
    }
    return FilePicker.getDirectoryPath(dialogTitle: '选择文件夹');
  }
}
