import 'package:flutter_test/flutter_test.dart';
import 'package:pic_sync/ui/format.dart';

void main() {
  test('formatBytes', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(3 * 1024 * 1024 * 1024), '3.00 GB');
  });
}
