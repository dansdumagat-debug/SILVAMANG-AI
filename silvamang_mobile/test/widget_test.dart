import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:silvamang_mobile/app.dart';
import 'package:silvamang_mobile/core/routing/app_router.dart';
import 'package:silvamang_mobile/core/routing/route_names.dart';
import 'package:silvamang_mobile/features/identification/presentation/pages/guest_scan_page.dart';

void main() {
  testWidgets('SILVAMANG AI app smoke test', (WidgetTester tester) async {
    dotenv.loadFromString(envString: 'API_BASE_URL=https://example.test/api');

    await tester.pumpWidget(const ProviderScope(child: SilvamangApp()));
    await tester.pumpAndSettle();

    expect(find.text('SILVAMANG AI'), findsWidgets);
    expect(find.textContaining('Discover a'), findsOneWidget);
    expect(find.byTooltip('Log in'), findsNothing);
    expect(find.byKey(const Key('guest-login-button')), findsOneWidget);
    expect(find.byKey(const Key('guest-register-button')), findsOneWidget);
    expect(find.text('Location Validation'), findsNothing);
    expect(find.byIcon(Icons.add_photo_alternate_rounded), findsNothing);
    expect(find.text('Take photo'), findsNothing);

    await tester.ensureVisible(find.text('Leaves'));
    await tester.tap(find.text('Leaves'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_photo_alternate_rounded), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);

    await tester.ensureVisible(find.text('Leaves'));
    await tester.tap(find.text('Leaves'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_photo_alternate_rounded), findsNothing);
    expect(find.text('Take photo'), findsNothing);

    AppRouter.router.goNamed(RouteNames.locationValidation);
    await tester.pumpAndSettle();
    expect(find.byType(GuestScanPage), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('guest-login-button')));
    await tester.tap(find.byKey(const Key('guest-login-button')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('guest scan fits a narrow phone', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GuestScanPage())),
    );
    await tester.ensureVisible(find.text('Leaves'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leaves'));
    await tester.pumpAndSettle();

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
