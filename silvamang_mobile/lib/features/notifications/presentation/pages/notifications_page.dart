import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../offline_sync/presentation/controllers/offline_sync_controller.dart';
import '../controllers/notification_controller.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    await ref.read(offlineSyncControllerProvider.notifier).loadQueue();
    await ref.read(authControllerProvider.notifier).refreshCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    final offlineState = ref.watch(offlineSyncControllerProvider);
    final notifications = ref.watch(appNotificationsProvider);
    final readIds = ref.watch(notificationReadControllerProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

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
                        : () => ref
                              .read(notificationReadControllerProvider.notifier)
                              .markAllRead(notifications),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SilvamangButton(
              text: 'Reset Unread State',
              icon: Icons.mark_email_unread_rounded,
              type: SilvamangButtonType.outline,
              onPressed: readIds.isEmpty
                  ? null
                  : () => ref
                        .read(notificationReadControllerProvider.notifier)
                        .resetUnread(),
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
                    isRead: notification.isRead(readIds),
                    onMarkRead: () => ref
                        .read(notificationReadControllerProvider.notifier)
                        .markRead(notification),
                    onOpen: notification.routeName == null
                        ? null
                        : () async {
                            await ref
                                .read(
                                  notificationReadControllerProvider.notifier,
                                )
                                .markRead(notification);
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
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isRead,
    required this.onMarkRead,
    required this.onOpen,
  });

  final AppNotification notification;
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
                          label: notification.readKeys.isEmpty
                              ? 'Info'
                              : isRead
                              ? 'Read'
                              : 'New',
                          type: notification.readKeys.isEmpty || isRead
                              ? SilvamangBadgeType.neutral
                              : SilvamangBadgeType.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(notification.message, style: AppTextStyles.bodyMedium),
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
