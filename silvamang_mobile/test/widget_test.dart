import 'package:flutter_test/flutter_test.dart';

import 'package:silvamang_mobile/app.dart';

void main() {
  testWidgets('SILVAMANG AI app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SilvamangApp());

    expect(find.text('SILVAMANG AI'), findsWidgets);
  });
}
