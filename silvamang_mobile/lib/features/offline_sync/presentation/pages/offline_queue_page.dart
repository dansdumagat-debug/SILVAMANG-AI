import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../data/models/offline_sync_item.dart';
import '../controllers/offline_sync_controller.dart';

class OfflineQueuePage extends ConsumerStatefulWidget {
  const OfflineQueuePage({super.key});

  @override
  ConsumerState<OfflineQueuePage> createState() => _OfflineQueuePageState();
}

class _OfflineQueuePageState extends ConsumerState<OfflineQueuePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(offlineSyncControllerProvider.notifier).loadQueue(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlineSyncControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(
          fallbackRouteName: RouteNames.records,
        ),
        title: const Text('Offline Queue'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          _StatusCard(
            title: state.isOnline ? 'Online' : 'Offline',
            subtitle: state.isOnline
                ? 'Manual sync is available.'
                : 'Connect to the internet to sync.',
            icon: state.isOnline
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded,
            color: state.isOnline
                ? AppColors.successGreen
                : AppColors.warningOrange,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Pending',
                  value: state.pendingCount.toString(),
                  color: AppColors.warningOrange,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryCard(
                  label: 'Failed',
                  value: state.failedCount.toString(),
                  color: AppColors.dangerRed,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SummaryCard(
                  label: 'Synced',
                  value: state.syncedCount.toString(),
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _SummaryCard(
            label: 'Recently Deleted',
            value: state.recentlyDeletedCount.toString(),
            color: AppColors.mutedText,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SilvamangButton(
                  text: 'Refresh Status',
                  icon: Icons.refresh_rounded,
                  type: SilvamangButtonType.outline,
                  onPressed: state.isLoading
                      ? null
                      : () => ref
                            .read(offlineSyncControllerProvider.notifier)
                            .loadQueue(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SilvamangButton(
                  text: 'Sync Now',
                  icon: Icons.cloud_upload_rounded,
                  isLoading: state.isSyncing,
                  onPressed: state.isSyncing
                      ? null
                      : () => ref
                            .read(offlineSyncControllerProvider.notifier)
                            .syncPendingItems(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SilvamangButton(
            text: 'Clear Synced',
            icon: Icons.cleaning_services_rounded,
            type: SilvamangButtonType.outline,
            onPressed: state.isSyncing || state.syncedCount == 0
                ? null
                : () => ref
                      .read(offlineSyncControllerProvider.notifier)
                      .clearSynced(),
          ),
          if (state.recentlyDeletedItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SilvamangButton(
              text: 'Clear Recently Deleted',
              icon: Icons.delete_forever_rounded,
              type: SilvamangButtonType.outline,
              onPressed: state.isSyncing
                  ? null
                  : () => ref
                        .read(offlineSyncControllerProvider.notifier)
                        .clearRecentlyDeleted(),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Text(
                state.errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.dangerRed,
                ),
              ),
            ),
          ],
          if (state.successMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Text(
                state.successMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.successGreen,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (state.items.isEmpty)
            const EmptyState(
              title: 'No active sync items.',
              message:
                  'Offline scans will appear here before manual sync. Cleared synced items can be restored from Recently Deleted.',
              icon: Icons.cloud_queue_rounded,
            )
          else
            ...state.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _QueueItemCard(
                  item: item,
                  isSyncing: state.isSyncing,
                  onRetry: () => ref
                      .read(offlineSyncControllerProvider.notifier)
                      .retryItem(item.id),
                  onRemove: () => ref
                      .read(offlineSyncControllerProvider.notifier)
                      .removeItem(item.id),
                ),
              ),
            ),
          if (state.recentlyDeletedItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Recently Deleted', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Restore synced queue records here if they were removed by accident.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ...state.recentlyDeletedItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _DeletedQueueItemCard(
                  item: item,
                  isSyncing: state.isSyncing,
                  onRestore: () => ref
                      .read(offlineSyncControllerProvider.notifier)
                      .restoreRecentlyDeletedItem(item.id),
                  onDeleteForever: () => ref
                      .read(offlineSyncControllerProvider.notifier)
                      .permanentlyDeleteRecentlyDeletedItem(item.id),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.metricValue.copyWith(color: color)),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTextStyles.titleMedium),
          Text(subtitle, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _QueueItemCard extends StatelessWidget {
  const _QueueItemCard({
    required this.item,
    required this.isSyncing,
    required this.onRetry,
    required this.onRemove,
  });

  final OfflineSyncItem item;
  final bool isSyncing;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _cleanLabel(item.type),
                  style: AppTextStyles.titleMedium,
                ),
              ),
              SilvamangBadge(
                label: _cleanLabel(item.status),
                type: _badgeType(item.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Created: ${_dateLabel(item.createdAt)}',
            style: AppTextStyles.bodySmall,
          ),
          Text(
            'Last attempt: ${item.lastAttemptAt == null ? 'Not yet' : _dateLabel(item.lastAttemptAt!)}',
            style: AppTextStyles.bodySmall,
          ),
          Text('Retries: ${item.retryCount}', style: AppTextStyles.bodySmall),
          if (item.syncedAt != null)
            Text(
              'Synced: ${_dateLabel(item.syncedAt!)}',
              style: AppTextStyles.bodySmall,
            ),
          if (item.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.errorMessage!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.dangerRed,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (item.status == OfflineSyncItem.statusFailed ||
                  item.status == OfflineSyncItem.statusPending)
                Expanded(
                  child: SilvamangButton(
                    text: item.status == OfflineSyncItem.statusFailed
                        ? 'Retry'
                        : 'Sync',
                    icon: Icons.refresh_rounded,
                    type: SilvamangButtonType.outline,
                    onPressed: isSyncing ? null : onRetry,
                  ),
                ),
              if (item.status == OfflineSyncItem.statusFailed ||
                  item.status == OfflineSyncItem.statusPending)
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SilvamangButton(
                  text: 'Remove',
                  icon: Icons.delete_outline_rounded,
                  type: SilvamangButtonType.outline,
                  onPressed: isSyncing ? null : onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SilvamangBadgeType _badgeType(String status) {
    return switch (status) {
      OfflineSyncItem.statusSynced => SilvamangBadgeType.success,
      OfflineSyncItem.statusFailed => SilvamangBadgeType.danger,
      OfflineSyncItem.statusSyncing => SilvamangBadgeType.info,
      _ => SilvamangBadgeType.warning,
    };
  }
}

class _DeletedQueueItemCard extends StatelessWidget {
  const _DeletedQueueItemCard({
    required this.item,
    required this.isSyncing,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final OfflineSyncItem item;
  final bool isSyncing;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _cleanLabel(item.type),
                  style: AppTextStyles.titleMedium,
                ),
              ),
              const SilvamangBadge(
                label: 'Deleted',
                type: SilvamangBadgeType.neutral,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Created: ${_dateLabel(item.createdAt)}',
            style: AppTextStyles.bodySmall,
          ),
          if (item.syncedAt != null)
            Text(
              'Synced: ${_dateLabel(item.syncedAt!)}',
              style: AppTextStyles.bodySmall,
            ),
          Text(
            'Deleted: ${item.deletedAt == null ? 'Recently' : _dateLabel(item.deletedAt!)}',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SilvamangButton(
                  text: 'Restore',
                  icon: Icons.restore_rounded,
                  type: SilvamangButtonType.outline,
                  onPressed: isSyncing ? null : onRestore,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SilvamangButton(
                  text: 'Delete',
                  icon: Icons.delete_forever_rounded,
                  type: SilvamangButtonType.outline,
                  onPressed: isSyncing ? null : onDeleteForever,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _cleanLabel(String value) {
  final label = value.replaceAll('_', ' ').trim();
  if (label.isEmpty) {
    return 'N/A';
  }

  return label
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _dateLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.year}-$month-$day $hour:$minute';
}
