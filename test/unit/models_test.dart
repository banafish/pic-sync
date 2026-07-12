import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pic_sync/models/announce.dart';
import 'package:pic_sync/models/manifest.dart';
import 'package:pic_sync/models/settings.dart';

void main() {
  group('Manifest', () {
    test('JSON 往返', () {
      final m = Manifest(deviceId: 'id-1', name: '设备A', files: const [
        ManifestFile(path: '0/旅行/IMG_001.jpg', name: 'IMG_001.jpg', folder: '旅行', size: 123),
      ]);
      final back = Manifest.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>);
      expect(back.deviceId, 'id-1');
      expect(back.files.single.path, '0/旅行/IMG_001.jpg');
      expect(back.files.single.folder, '旅行');
      expect(back.files.single.size, 123);
    });
  });

  group('AnnounceMessage', () {
    test('编解码往返', () {
      final msg = const AnnounceMessage(deviceId: 'd1', name: '小米', httpPort: 45655);
      final back = AnnounceMessage.tryParse(msg.encode());
      expect(back, isNotNull);
      expect(back!.deviceId, 'd1');
      expect(back.name, '小米');
      expect(back.httpPort, 45655);
    });
    test('非本应用报文返回 null', () {
      expect(AnnounceMessage.tryParse('{"app":"other","ver":1}'), isNull);
      expect(AnnounceMessage.tryParse('{"app":"picsync","ver":2,"deviceId":"x","name":"y","httpPort":1}'), isNull);
      expect(AnnounceMessage.tryParse('not json'), isNull);
      expect(AnnounceMessage.tryParse('{"app":"picsync","ver":1,"deviceId":"x"}'), isNull);
    });
  });

  group('Settings', () {
    test('defaults 为空集合', () {
      final s = Settings.defaults(deviceId: 'id', deviceName: 'n');
      expect(s.shareDirs, isEmpty);
      expect(s.defaultRecvDir, '');
      expect(s.issuedTokens, isEmpty);
      expect(s.peerTokens, isEmpty);
      expect(s.manualHosts, isEmpty);
    });
    test('JSON 往返', () {
      final s = Settings.defaults(deviceId: 'id', deviceName: '我的电脑')
        ..shareDirs.add('D:/照片')
        ..defaultRecvDir = 'D:/照片/收到'
        ..issuedTokens['peer1'] = 'tokA'
        ..peerTokens['peer1'] = 'tokB'
        ..peerNames['peer1'] = '手机'
        ..manualHosts.add('192.168.1.9');
      final back = Settings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.deviceId, 'id');
      expect(back.shareDirs, ['D:/照片']);
      expect(back.defaultRecvDir, 'D:/照片/收到');
      expect(back.issuedTokens['peer1'], 'tokA');
      expect(back.peerTokens['peer1'], 'tokB');
      expect(back.peerNames['peer1'], '手机');
      expect(back.manualHosts, ['192.168.1.9']);
    });
    test('缺失字段容错', () {
      final back = Settings.fromJson({'deviceId': 'id', 'deviceName': 'n'});
      expect(back.shareDirs, isEmpty);
      expect(back.defaultRecvDir, '');
    });
  });
}
