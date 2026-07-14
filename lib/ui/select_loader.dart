import '../models/device.dart';
import '../models/manifest.dart';
import '../services/diff_engine.dart';
import '../services/http_client.dart';
import '../services/library_scanner.dart';
import 'app_state.dart';

class SelectLoadResult {
  SelectLoadResult({
    required this.client,
    required this.manifest,
    required this.diff,
    required this.remotePerFolder,
  });
  final PeerClient client;
  final Manifest manifest;
  final DiffResult diff;
  final Map<String, int> remotePerFolder;
}

class SelectLoader {
  Future<SelectLoadResult> load(AppState app, Device device,
      {void Function(String status)? onStatus}) async {
    onStatus?.call('等待对方确认…（首次连接需在对方设备上同意）');
    var client = await app.connect(device);
    onStatus?.call('正在获取清单…');
    Manifest manifest;
    try {
      manifest = await client.fetchManifest();
    } on Unauthorized {
      await app.forgetPeerToken(device.deviceId);
      onStatus?.call('等待对方确认…（授权已失效，需重新配对）');
      client = await app.connect(device);
      manifest = await client.fetchManifest();
    }
    onStatus?.call('正在扫描本机…');
    final local = await LibraryScanner().scan(app.settings.shareDirs);
    final diff = computeMissing(manifest.files, local);
    final perFolder = <String, int>{};
    for (final f in manifest.files) {
      perFolder[f.folder] = (perFolder[f.folder] ?? 0) + 1;
    }
    return SelectLoadResult(
        client: client, manifest: manifest, diff: diff, remotePerFolder: perFolder);
  }
}
