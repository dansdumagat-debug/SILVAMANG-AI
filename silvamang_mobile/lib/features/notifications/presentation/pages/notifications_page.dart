import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../offline_sync/presentation/controllers/offline_sync_controller.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  static const _readStorageKey = 'app_notification_read_ids';

  final _storage = LocalStorageService.instance;
  Set<String> _readIds = <String>{};

  @override
  void initState() {
    super.initState();
    _readIds = _loadReadIds();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    await ref.read(offlineSyncControllerProvider.notifier).loadQueue();
    await ref.read(authControllerProvider.notifier).refreshCurrentUser();
  }

  Future<void> _markAllRead(List<_AppNotification> notifications) async {
    setState(() {
      _readIds = {
        ..._readIds,
        for (final notification in notifications) notification.id,
      };
    });
    await _saveReadIds();
  }

  Future<void> _markRead(_AppNotification notification) async {
    if (_readIds.contains(notification.id)) {
      return;
    }

    setState(() => _readIds = {..._readIds, notification.id});
    await _saveReadIds();
  }

  Future<void> _resetUnread() async {
    setState(() => _readIds = <String>{});
    await _saveReadIds();
  }

  Set<String> _loadReadIds() {
    final raw = _storage.getString(_readStorageKey);
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((value) => value.toString()).toSet();
      }
    } catch (_) {
      return <String>{};
    }

    return <String>{};
  }

  Future<void> _saveReadIds() {
    return _storage.saveString(_readStorageKey, jsonEncode(_readIds.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final offlineState = ref.watch(offlineSyncControllerProvider);
    final notifications = _notificationsFor(authState, offlineState);
    final unreadCount = notifications
        .where((notification) => !_readIds.contains(notification.id))
        .length;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(fallbackRouteName: RouteNames.home),
        title: const Text('Notifications'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.screenPadding,
            AppConstants.screenPadding,
            AppConstants.screenPadding,
            112,
          ),
          children: [
            SilvamangCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.primaryDarkGreen,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Notification Center',
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      SilvamangBadge(
                        label: '$unreadCount unread',
                        type: unreadCount == 0
                            ? SilvamangBadgeType.success
                            : SilvamangBadgeType.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Track sync issues, offline status, deleted queue records, and field map reminders here.',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: SilvamangButton(
                    text: 'Refresh',
                    icon: Icons.refresh_rounded,
                    type: SilvamangButtonType.outline,
                    onPressed: offlineState.isLoading ? null : _refresh,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SilvamangButton(
                    text: 'Mark Read',
                    icon: Icons.done_all_rounded,
                    type: SilvamangButtonType.outline,
                    onPressed: notifications.isEmpty
                        ? null
                        : () => _markAllRead(notifications),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SilvamangButton(
              text: 'Reset Unread State',
              icon: Icons.mark_email_unread_rounded,
              type: SilvamangButtonType.outline,
              onPressed: _readIds.isEmpty ? null : _resetUnread,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (notifications.isEmpty)
              const EmptyState(
                title: 'No active notifications.',
                message:
                    'Sync alerts, offline session notices, and field reminders will appear here.',
                icon: Icons.notifications_none_rounded,
              )
            else
              ...notifications.map(
                (notification) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _NotificationCard(
                    notification: notification,
                    isRead: _readIds.contains(notification.id),
                    onMarkRead: () => _markRead(notification),
                    onOpen: notification.routeName == null
                        ? null
                        : () async {
                            await _markRead(notification);
                            if (context.mounted) {
                              context.pushNamed(notification.routeName!);
                            }
                          },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_AppNotification> _notificationsFor(
    AuthState authState,
    OfflineSyncState offlineState,
  ) {
    final notifications = <_AppNotification>[];

    if (authState.isOfflineSession) {
      notifications.add(
        const _AppNotification(
          id: 'auth.offline_session',
          title: 'Offline session active',
          message:
              'The app cannot reach the Laravel API right now. Saved scans will sync when the server is reachable again.',
          icon: Icons.cloud_off_rounded,
          color: AppColors.warningOrange,
          routeName: RouteNames.appSettings,
        ),
      );
    }

    if (offlineState.pendingCount > 0) {
      notifications.add(
        _AppNotification(
          id: 'sync.pending.${offlineState.pendingCount}',
          title: 'Pending sync items',
          message:
              '${offlineState.pendingCount} offline scan item(s) are waiting to be uploaded.',
          icon: Icons.cloud_upload_rounded,
          color: AppColors.warningOrange,
          routeName: RouteNames.offlineQueue,
        ),
      );
    }

    if (offlineState.failedCount > 0) {
      notifications.add(
        _AppNotification(
          id: 'sync.failed.${offlineState.failedCount}',
          title: 'Sync needs attention',
          message:
              '${offlineState.failedCount} item(s) failed to sync. Open the queue to retry.',
          icon: Icons.error_outline_rounded,
          color: AppColors.dangerRed,
          routeName: RouteNames.offlineQueue,
        ),
      );
    }

    if (offlineState.recentlyDeletedCount > 0) {
      notifications.add(
        _AppNotification(
          id: 'sync.deleted.${offlineState.recentlyDeletedCount}',
          title: 'Recently deleted queue records',
          message:
              '${offlineState.recentlyDeletedCount} deleted item(s) can still be restored.',
          icon: Icons.restore_from_trash_rounded,
          color: AppColors.mutedText,
          routeName: RouteNames.offlineQueue,
        ),
      );
    }

    notifications.add(
      const _AppNotification(
        id: 'map.offline_download_reminder',
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
}

class _AppNotification {
  const _AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.routeName,
  });

  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String? routeName;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isRead,
    required this.onMarkRead,
    required this.onOpen,
  });

  final _AppNotification notification;
  final bool isRead;
  final VoidCallback onMarkRead;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      onTap: onMarkRead,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: notification.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(notification.icon, color: notification.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.titleMedium,
                          ),
                        ),
                        SilvamangBadge(
                          label: isRead ? 'Read' : 'New',
                          type: isRead
                              ? SilvamangBadgeType.neutral
                              : SilvamangBadgeType.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.message,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onOpen != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
