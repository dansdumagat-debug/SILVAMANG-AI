import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:silvamang_mobile/app.dart';

void main() {
  testWidgets('SILVAMANG AI app smoke test', (WidgetTester tester) async {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=https://example.test/api',
    );

    await tester.pumpWidget(const ProviderScope(child: SilvamangApp()));

    expect(find.text('SILVAMANG AI'), findsWidgets);
  });
}
