import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:silvamang_mobile/core/routing/route_names.dart';
import 'package:silvamang_mobile/core/services/connectivity_service.dart';
import 'package:silvamang_mobile/core/services/local_storage_service.dart';
import 'package:silvamang_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:silvamang_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:silvamang_mobile/features/home/presentation/pages/home_page.dart';
import 'package:silvamang_mobile/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:silvamang_mobile/features/notifications/presentation/pages/notifications_page.dart';
import 'package:silvamang_mobile/features/offline_sync/data/models/offline_sync_item.dart';
import 'package:silvamang_mobile/features/offline_sync/data/repositories/offline_sync_repository.dart';
import 'package:silvamang_mobile/features/offline_sync/presentation/controllers/offline_sync_controller.dart';
import 'package:silvamang_mobile/features/records/data/repositories/scan_record_repository.dart';
import 'package:silvamang_mobile/features/records/presentation/controllers/records_controller.dart';

class _UnusedAuthRepository extends Fake implements AuthRepository {}

class _UnusedOfflineSyncRepository extends Fake
    implements OfflineSyncRepository {}

class _UnusedScanRecordRepository extends Fake
    implements ScanRecordRepository {}

class _TestAuthController extends AuthController {
  _TestAuthController()
    : super(
        repository: _UnusedAuthRepository(),
        storage: LocalStorageService.instance,
      ) {
    state = const AuthState(token: 'test-token', isOfflineSession: true);
  }

  @override
  Future<bool> refreshCurrentUser() async => true;
}

class _TestOfflineSyncController extends OfflineSyncController {
  _TestOfflineSyncController()
    : super(
        connectivityService: const ConnectivityService(),
        offlineSyncRepository: _UnusedOfflineSyncRepository(),
        scanRecordRepository: _UnusedScanRecordRepository(),
        currentUserId: null,
        currentUserEmail: null,
      );

  @override
  Future<void> loadQueue() async {}
}

class _TestRecordsController extends RecordsController {
  _TestRecordsController() : super(repository: _UnusedScanRecordRepository());

  @override
  Future<void> loadRecords() async {}
}

OfflineSyncItem _item(String id) => OfflineSyncItem(
  id: id,
  type: OfflineSyncItem.typeScanRecordMockSave,
  payloadJson: '{}',
  status: OfflineSyncItem.statusPending,
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  testWidgets('reading a notification clears the Home badge on return', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          name: RouteNames.home,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/notifications',
          name: RouteNames.notifications,
          builder: (context, state) => const NotificationsPage(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          offlineSyncControllerProvider.overrideWith(
            (ref) => _TestOfflineSyncController(),
          ),
          recordsControllerProvider.overrideWith(
            (ref) => _TestRecordsController(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_notification_badge')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1 unread'), findsOneWidget);

    await tester.tap(find.text('Mark Read'));
    await tester.pumpAndSettle();
    expect(find.text('0 unread'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byKey(const Key('home_notification_badge')), findsNothing);
  });

  test('reading pending items stays read when the count decreases', () {
    final initial = buildAppNotifications(
      const AuthState(),
      OfflineSyncState(items: [_item('a'), _item('b')]),
    );
    final pending = initial.singleWhere(
      (notification) => notification.id == 'sync.pending',
    );
    final readIds = pending.readKeys.toSet();

    final afterRemoval = buildAppNotifications(
      const AuthState(),
      OfflineSyncState(items: [_item('b')]),
    );
    expect(
      afterRemoval
          .singleWhere((notification) => notification.id == 'sync.pending')
          .isRead(readIds),
      isTrue,
    );

    final afterNewItem = buildAppNotifications(
      const AuthState(),
      OfflineSyncState(items: [_item('b'), _item('c')]),
    );
    expect(
      afterNewItem
          .singleWhere((notification) => notification.id == 'sync.pending')
          .isRead(readIds),
      isFalse,
    );
  });
}
