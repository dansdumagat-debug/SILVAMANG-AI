import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:silvamang_mobile/core/routing/route_names.dart';
import 'package:silvamang_mobile/core/services/local_storage_service.dart';
import 'package:silvamang_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:silvamang_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:silvamang_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:silvamang_mobile/features/auth/presentation/pages/register_page.dart';

class _UnusedRepository extends Fake implements AuthRepository {}

void main() {
  Future<GoRouter> openApp(WidgetTester tester) async {
    tester.view.reset();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/guest',
      routes: [
        GoRoute(
          path: '/guest',
          name: RouteNames.guestScan,
          builder: (_, _) => const Scaffold(body: Text('Landing page')),
        ),
        GoRoute(
          path: '/login',
          name: RouteNames.login,
          builder: (_, _) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          name: RouteNames.register,
          builder: (_, _) => const RegisterPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => AuthController(
              repository: _UnusedRepository(),
              storage: LocalStorageService.instance,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('login arrow returns to landing even with register behind it', (
    tester,
  ) async {
    final router = await openApp(tester);
    router.pushNamed(RouteNames.register);
    await tester.pumpAndSettle();
    router.pushNamed(RouteNames.login);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back').last);
    await tester.pumpAndSettle();
    expect(find.text('Landing page'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('register login link and Android back return to landing', (
    tester,
  ) async {
    final router = await openApp(tester);
    router.pushNamed(RouteNames.login);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Landing page'), findsOneWidget);
  });
}
