import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/settings.dart';

String _defaultDeviceName() {
  try {
    if (Platform.isWindows) return Platform.localHostname;
  } catch (_) {}
  return 'PicSync-${Platform.operatingSystem}';
}

class SettingsStore {
  SettingsStore(this.filePath);
  final String filePath;

  Future<Settings> load() async {
    final file = File(filePath);
    if (await file.exists()) {
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        return Settings.fromJson(json);
      } catch (_) {
        // 落到重建
      }
    }
    final fresh = Settings.defaults(
      deviceId: const Uuid().v4(),
      deviceName: _defaultDeviceName(),
    );
    await save(fresh);
    return fresh;
  }

  Future<void> save(Settings s) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final tmp = File('$filePath.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(s.toJson()));
    await tmp.rename(filePath);
  }
}
