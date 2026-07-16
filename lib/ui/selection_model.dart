import 'package:flutter/foundation.dart';
import '../models/manifest.dart';
import '../services/diff_engine.dart';

class SelectionModel extends ChangeNotifier {
  SelectionModel(DiffResult diff) : groups = diff.byFolder {
    for (final f in diff.missing) {
      _selected.add(f.path);
    }
  }

  final Map<String, List<ManifestFile>> groups;
  final Set<String> _selected = {};

  bool isSelected(ManifestFile f) => _selected.contains(f.path);
  int get selectedCount => _selected.length;

  int get totalMissingCount =>
      groups.values.fold(0, (sum, files) => sum + files.length);

  bool get isAllSelected =>
      totalMissingCount > 0 && selectedCount == totalMissingCount;

  void selectAll() {
    for (final g in groups.values) {
      for (final f in g) {
        _selected.add(f.path);
      }
    }
    notifyListeners();
  }

  void deselectAll() {
    _selected.clear();
    notifyListeners();
  }

  int selectedCountIn(String folder) =>
      (groups[folder] ?? const []).where(isSelected).length;

  bool folderFullySelected(String folder) {
    final g = groups[folder] ?? const [];
    return g.isNotEmpty && g.every(isSelected);
  }

  void toggleFile(ManifestFile f) {
    if (!_selected.remove(f.path)) _selected.add(f.path);
    notifyListeners();
  }

  void toggleFolder(String folder) {
    final g = groups[folder] ?? const [];
    if (folderFullySelected(folder)) {
      for (final f in g) {
        _selected.remove(f.path);
      }
    } else {
      for (final f in g) {
        _selected.add(f.path);
      }
    }
    notifyListeners();
  }

  List<ManifestFile> get selectedFiles =>
      [for (final g in groups.values) for (final f in g) if (isSelected(f)) f];

  int get selectedBytes => selectedFiles.fold(0, (s, f) => s + f.size);
}
