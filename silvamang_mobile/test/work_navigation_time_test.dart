import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/core/routing/work_navigation_observer.dart';
import 'package:silvamang_mobile/core/utils/formatters.dart';

void main() {
  test(
    'Philippine time crosses date boundary and respects explicit offsets',
    () {
      expect(
        Formatters.dateTime(DateTime.parse('2026-10-04T17:05:00Z')),
        'Oct 5, 2026 1:05 AM PHT',
      );
      expect(
        Formatters.dateTime(DateTime.parse('2026-10-05T01:05:00+08:00')),
        'Oct 5, 2026 1:05 AM PHT',
      );
    },
  );

  testWidgets('resume preserves typed form after switching multiple features', (
    tester,
  ) async {
    final observer = WorkNavigationObserver();
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('Home')),
      ),
    );
    key.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'manualSpeciesMeasurement'),
        builder: (_) => const Scaffold(body: TextField()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '174');
    for (final name in ['records', 'profile']) {
      key.currentState!.push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => Scaffold(body: Text(name)),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(observer.unfinishedRoute?.settings.name, 'manualSpeciesMeasurement');
    expect(observer.resume(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('174'), findsOneWidget);
    expect(observer.unfinishedRoute, isNull);
  });
}
