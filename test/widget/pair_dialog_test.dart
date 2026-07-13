import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pic_sync/ui/pair_dialog.dart';

void main() {
  testWidgets('同意返回 true，拒绝返回 false', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const Scaffold()));

    final f1 = showPairDialog(key, '手机A');
    await tester.pumpAndSettle();
    expect(find.textContaining('手机A'), findsOneWidget);
    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();
    expect(await f1, isTrue);

    final f2 = showPairDialog(key, '手机B');
    await tester.pumpAndSettle();
    await tester.tap(find.text('拒绝'));
    await tester.pumpAndSettle();
    expect(await f2, isFalse);
  });
}
