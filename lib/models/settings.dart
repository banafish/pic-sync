class Settings {
  String deviceId;
  String deviceName;
  List<String> shareDirs;
  String defaultRecvDir; // '' 表示未设置
  Map<String, String> issuedTokens; // 对方 deviceId -> 我签发的 token（服务端校验）
  Map<String, String> peerTokens; // 对方 deviceId -> 对方签发给我的 token（客户端携带）
  Map<String, String> peerNames; // 对方 deviceId -> 显示名
  List<String> manualHosts; // "192.168.1.23" 或 "192.168.1.23:45656"
  Map<String, Map<String, String>> peerFolderOverrides; // 对方 deviceId -> (小写远程文件夹名 -> 本地保存路径)

  Settings({
    required this.deviceId,
    required this.deviceName,
    required this.shareDirs,
    required this.defaultRecvDir,
    required this.issuedTokens,
    required this.peerTokens,
    required this.peerNames,
    required this.manualHosts,
    Map<String, Map<String, String>>? peerFolderOverrides,
  }) : peerFolderOverrides = peerFolderOverrides ?? {};

  factory Settings.defaults({required String deviceId, required String deviceName}) => Settings(
        deviceId: deviceId,
        deviceName: deviceName,
        shareDirs: [],
        defaultRecvDir: '',
        issuedTokens: {},
        peerTokens: {},
        peerNames: {},
        manualHosts: [],
        peerFolderOverrides: {},
      );

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        shareDirs: (json['shareDirs'] as List? ?? []).cast<String>().toList(),
        defaultRecvDir: json['defaultRecvDir'] as String? ?? '',
        issuedTokens: (json['issuedTokens'] as Map? ?? {}).cast<String, String>(),
        peerTokens: (json['peerTokens'] as Map? ?? {}).cast<String, String>(),
        peerNames: (json['peerNames'] as Map? ?? {}).cast<String, String>(),
        manualHosts: (json['manualHosts'] as List? ?? []).cast<String>().toList(),
        peerFolderOverrides: (json['peerFolderOverrides'] as Map? ?? {}).map(
          (k, v) => MapEntry(
            k as String,
            (v as Map? ?? {}).cast<String, String>(),
          ),
        ),
      );

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'shareDirs': shareDirs,
        'defaultRecvDir': defaultRecvDir,
        'issuedTokens': issuedTokens,
        'peerTokens': peerTokens,
        'peerNames': peerNames,
        'manualHosts': manualHosts,
        'peerFolderOverrides': peerFolderOverrides,
      };
}
