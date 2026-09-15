import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../data/models/transect_record_model.dart';
import '../controllers/transects_controller.dart';

enum _HistoryFilter { all, gps, manual }

class TransectHistoryPage extends ConsumerStatefulWidget {
  const TransectHistoryPage({super.key});

  @override
  ConsumerState<TransectHistoryPage> createState() =>
      _TransectHistoryPageState();
}

class _TransectHistoryPageState extends ConsumerState<TransectHistoryPage> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(transectsControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transectsControllerProvider);
    final records = state.records.where((record) {
      return switch (_filter) {
        _HistoryFilter.all => true,
        _HistoryFilter.gps => record.isGpsTracking,
        _HistoryFilter.manual => !record.isGpsTracking,
      };
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('Digital Transects'),
        actions: [
          IconButton(
            tooltip: 'Synchronize transects',
            onPressed: state.isSyncing
                ? null
                : () => ref
                      .read(transectsControllerProvider.notifier)
                      .syncPending(),
            icon: state.isSyncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(transectsControllerProvider.notifier).load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppConstants.screenPadding,
            AppConstants.screenPadding,
            AppConstants.screenPadding,
            132,
          ),
          children: [
            _ConnectionBanner(
              isOnline: state.isOnline,
              pendingCount: state.pendingCount,
              hasServerWarning: state.errorMessage != null,
            ),
            const SizedBox(height: AppSpacing.md),
            SilvamangButton(
              text: 'Create Transect',
              icon: Icons.add_location_alt_rounded,
              onPressed: () => context.pushNamed(RouteNames.transectCreate),
            ),
            const SizedBox(height: AppSpacing.md),
            _MetricStrip(state: state),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<_HistoryFilter>(
              segments: const [
                ButtonSegment(
                  value: _HistoryFilter.all,
                  icon: Icon(Icons.view_list_rounded),
                  label: Text('All'),
                ),
                ButtonSegment(
                  value: _HistoryFilter.gps,
                  icon: Icon(Icons.route_rounded),
                  label: Text('GPS'),
                ),
                ButtonSegment(
                  value: _HistoryFilter.manual,
                  icon: Icon(Icons.touch_app_rounded),
                  label: Text('Manual'),
                ),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
            ),
            if (state.isLoading) ...[
              const SizedBox(height: AppSpacing.lg),
              const LinearProgressIndicator(),
            ],
            if (state.successMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              _MessageBanner(
                message: state.successMessage!,
                color: AppColors.successGreen,
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              _MessageBanner(
                message: state.errorMessage!,
                color: AppColors.warningOrange,
                icon: Icons.info_outline_rounded,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (!state.isLoading && records.isEmpty)
              EmptyState(
                title: state.records.isEmpty
                    ? 'No transects yet'
                    : 'No matching transects',
                message: state.records.isEmpty
                    ? 'Record a GPS path or mark its start and end on the map.'
                    : 'Choose another mode to see your saved transects.',
                icon: Icons.route_rounded,
              )
            else
              ...records.map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _TransectCard(record: record),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.isOnline,
    required this.pendingCount,
    required this.hasServerWarning,
  });

  final bool isOnline;
  final int pendingCount;
  final bool hasServerWarning;

  @override
  Widget build(BuildContext context) {
    final cloudAvailable = isOnline && !hasServerWarning;
    final color = cloudAvailable
        ? AppColors.successGreen
        : AppColors.warningOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            cloudAvailable ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasServerWarning
                  ? 'Transect cloud service is unavailable. Saved field records remain on this device.'
                  : isOnline
                  ? pendingCount == 0
                        ? 'Online. Your transects are synchronized.'
                        : 'Online. $pendingCount transect(s) are waiting to sync.'
                  : 'Offline. Field records stay on this device until connection returns.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.state});

  final TransectsState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCell(
            label: 'Transects',
            value: '${state.records.length}',
            icon: Icons.route_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCell(
            label: 'Distance',
            value: _distance(state.totalDistanceM),
            icon: Icons.straighten_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _MetricCell(
            label: 'Scans',
            value: '${state.observationCount}',
            icon: Icons.eco_rounded,
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primaryGreen),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMedium,
          ),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _TransectCard extends StatelessWidget {
  const _TransectCard({required this.record});

  final TransectRecordModel record;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.syncStatus) {
      TransectRecordModel.syncSynced => AppColors.successGreen,
      TransectRecordModel.syncFailed => AppColors.dangerRed,
      _ => AppColors.warningOrange,
    };

    return SilvamangCard(
      onTap: () => context.pushNamed(
        RouteNames.transectDetail,
        pathParameters: {'id': record.localId},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: record.isGpsTracking
                      ? AppColors.softGreen
                      : AppColors.softBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  record.isGpsTracking
                      ? Icons.route_rounded
                      : Icons.touch_app_rounded,
                  color: AppColors.primaryDarkGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.transectName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.locationName?.trim().isNotEmpty == true
                          ? record.locationName!
                          : 'Location not named',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _syncLabel(record.syncStatus),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _InlineFact(
                icon: Icons.straighten_rounded,
                text: _distance(record.totalDistanceM),
              ),
              _InlineFact(
                icon: Icons.navigation_rounded,
                text: record.directionLabel,
              ),
              _InlineFact(
                icon: Icons.timeline_rounded,
                text: '${record.points.length} points',
              ),
              _InlineFact(
                icon: Icons.eco_rounded,
                text: '${record.observations.length} scans',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${record.displayCode}  ${DateFormat('MMM d, yyyy').format(record.recordedAt.toLocal())}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedText,
              ),
            ],
          ),
          if (record.syncError?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              record.syncError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.dangerRed,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineFact extends StatelessWidget {
  const _InlineFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primaryGreen),
        const SizedBox(width: 5),
        Text(text, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}

String _distance(double meters) {
  if (meters >= 1000) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
  return '${meters.toStringAsFixed(meters >= 100 ? 0 : 1)} m';
}

String _syncLabel(String status) {
  return switch (status) {
    TransectRecordModel.syncSynced => 'Synced',
    TransectRecordModel.syncFailed => 'Retry',
    _ => 'Pending',
  };
}
