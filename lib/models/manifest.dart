class ManifestFile {
  final String path;
  final String name;
  final String folder;
  final int size;
  const ManifestFile({required this.path, required this.name, required this.folder, required this.size});

  factory ManifestFile.fromJson(Map<String, dynamic> json) => ManifestFile(
        path: json['path'] as String,
        name: json['name'] as String,
        folder: json['folder'] as String,
        size: json['size'] as int,
      );

  Map<String, dynamic> toJson() => {'path': path, 'name': name, 'folder': folder, 'size': size};
}

class Manifest {
  final String deviceId;
  final String name;
  final List<ManifestFile> files;
  const Manifest({required this.deviceId, required this.name, required this.files});

  factory Manifest.fromJson(Map<String, dynamic> json) => Manifest(
        deviceId: json['deviceId'] as String,
        name: json['name'] as String,
        files: (json['files'] as List)
            .map((e) => ManifestFile.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() =>
      {'deviceId': deviceId, 'name': name, 'files': files.map((f) => f.toJson()).toList()};
}
