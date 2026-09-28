import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:flutter_riverpod/legacy.dart'
    show StateNotifier, StateNotifierProvider;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../offline_sync/data/models/offline_sync_item.dart';
import '../../../offline_sync/presentation/controllers/offline_sync_controller.dart';

final appNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final authState = ref.watch(authControllerProvider);
  final offlineState = ref.watch(offlineSyncControllerProvider);
  return buildAppNotifications(authState, offlineState);
});

final notificationReadControllerProvider =
    StateNotifierProvider<NotificationReadController, Set<String>>((ref) {
      return NotificationReadController(LocalStorageService.instance);
    });

final unreadNotificationCountProvider = Provider<int>((ref) {
  return countUnreadNotifications(
    ref.watch(appNotificationsProvider),
    ref.watch(notificationReadControllerProvider),
  );
});

class AppNotification {
  const AppNotification({
    required this.id,
    required this.readKeys,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.routeName,
  });

  final String id;
  final List<String> readKeys;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String? routeName;

  bool isRead(Set<String> readIds) =>
      readKeys.every((readKey) => readIds.contains(readKey));
}

class NotificationReadController extends StateNotifier<Set<String>> {
  NotificationReadController(this._storage) : super(_loadReadIds(_storage));

  static const _readStorageKey = 'app_notification_read_ids';
  final LocalStorageService _storage;

  Future<void> markRead(AppNotification notification) {
    if (notification.isRead(state)) {
      return Future<void>.value();
    }
    state = Set<String>.unmodifiable({...state, ...notification.readKeys});
    return _saveReadIds();
  }

  Future<void> markAllRead(List<AppNotification> notifications) {
    state = Set<String>.unmodifiable({
      ...state,
      for (final notification in notifications) ...notification.readKeys,
    });
    return _saveReadIds();
  }

  Future<void> resetUnread() {
    state = const <String>{};
    return _saveReadIds();
  }

  static Set<String> _loadReadIds(LocalStorageService storage) {
    final raw = storage.getString(_readStorageKey);
    if (raw == null || raw.isEmpty) {
      return const <String>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return Set<String>.unmodifiable(
          decoded.map((value) => value.toString()),
        );
      }
    } catch (_) {
      return const <String>{};
    }

    return const <String>{};
  }

  Future<void> _saveReadIds() {
    return _storage.saveString(_readStorageKey, jsonEncode(state.toList()));
  }
}

int countUnreadNotifications(
  List<AppNotification> notifications,
  Set<String> readIds,
) =>
    notifications.where((notification) => !notification.isRead(readIds)).length;

List<AppNotification> buildAppNotifications(
  AuthState authState,
  OfflineSyncState offlineState,
) {
  final notifications = <AppNotification>[];

  if (authState.isOfflineSession) {
    notifications.add(
      const AppNotification(
        id: 'auth.offline_session',
        readKeys: ['auth.offline_session'],
        title: 'Offline session active',
        message:
            'The app cannot reach the Laravel API right now. Saved scans will sync when the server is reachable again.',
        icon: Icons.cloud_off_rounded,
        color: AppColors.warningOrange,
        routeName: RouteNames.appSettings,
      ),
    );
  }

  final pendingItems = offlineState.items
      .where((item) => item.status == OfflineSyncItem.statusPending)
      .toList();
  if (pendingItems.isNotEmpty) {
    notifications.add(
      AppNotification(
        id: 'sync.pending',
        readKeys: [for (final item in pendingItems) 'sync.pending.${item.id}'],
        title: 'Pending sync items',
        message:
            '${pendingItems.length} offline scan item(s) are waiting to be uploaded.',
        icon: Icons.cloud_upload_rounded,
        color: AppColors.warningOrange,
        routeName: RouteNames.offlineQueue,
      ),
    );
  }

  final failedItems = offlineState.items
      .where((item) => item.status == OfflineSyncItem.statusFailed)
      .toList();
  if (failedItems.isNotEmpty) {
    notifications.add(
      AppNotification(
        id: 'sync.failed',
        readKeys: [
          for (final item in failedItems)
            'sync.failed.${item.id}.${item.retryCount}',
        ],
        title: 'Sync needs attention',
        message:
            '${failedItems.length} item(s) failed to sync. Open the queue to retry.',
        icon: Icons.error_outline_rounded,
        color: AppColors.dangerRed,
        routeName: RouteNames.offlineQueue,
      ),
    );
  }

  if (offlineState.recentlyDeletedItems.isNotEmpty) {
    notifications.add(
      AppNotification(
        id: 'sync.deleted',
        readKeys: [
          for (final item in offlineState.recentlyDeletedItems)
            'sync.deleted.${item.id}.${item.deletedAt?.toIso8601String() ?? ''}',
        ],
        title: 'Recently deleted queue records',
        message:
            '${offlineState.recentlyDeletedItems.length} deleted item(s) can still be restored.',
        icon: Icons.restore_from_trash_rounded,
        color: AppColors.mutedText,
        routeName: RouteNames.offlineQueue,
      ),
    );
  }

  notifications.add(
    const AppNotification(
      id: 'map.offline_download_reminder',
      readKeys: [],
      title: 'Offline map reminder',
      message:
          'Download a field map area before going offline. Scan pins can still save even if map tiles are unavailable.',
      icon: Icons.download_for_offline_rounded,
      color: AppColors.primaryGreen,
      routeName: RouteNames.offlineMapManager,
    ),
  );

  return notifications;
}
