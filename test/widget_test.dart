import 'package:flutter_test/flutter_test.dart';
import 'package:pic_sync/main.dart';

void main() {
  testWidgets('应用启动显示标题', (tester) async {
    await tester.pumpWidget(const PicSyncApp());
    expect(find.text('图片同步'), findsOneWidget);
  });
}
