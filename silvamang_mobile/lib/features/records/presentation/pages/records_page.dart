import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../../shared/models/scan_record_model.dart';
import '../controllers/records_controller.dart';

class RecordsPage extends ConsumerStatefulWidget {
  const RecordsPage({super.key});

  @override
  ConsumerState<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends ConsumerState<RecordsPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(recordsControllerProvider.notifier).loadRecords(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordsControllerProvider);
    final records = state.records;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('My Records'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(recordsControllerProvider.notifier).loadRecords(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          TextField(
            controller: _searchController,
            onSubmitted: (value) => ref
                .read(recordsControllerProvider.notifier)
                .searchRecords(value),
            decoration: InputDecoration(
              hintText: 'Search records...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () => ref
                    .read(recordsControllerProvider.notifier)
                    .searchRecords(_searchController.text),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final filter in const [
                'All',
                'Completed',
                'Pending',
                'Match',
                'Mismatch',
              ])
                _FilterChip(
                  label: filter,
                  selected: state.selectedFilter == filter,
                  onTap: () => ref
                      .read(recordsControllerProvider.notifier)
                      .filterRecords(filter),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            onTap: () => context.pushNamed(RouteNames.offlineQueue),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.cloud_queue_rounded,
                    color: AppColors.primaryDarkGreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Offline Queue', style: AppTextStyles.labelLarge),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedText,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (state.isLoading)
            const SizedBox(
              height: 260,
              child: LoadingView(message: 'Loading scan records...'),
            )
          else if (state.errorMessage != null)
            SilvamangCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unable to load records',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(state.errorMessage!, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  SilvamangButton(
                    text: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: () => ref
                        .read(recordsControllerProvider.notifier)
                        .loadRecords(),
                  ),
                ],
              ),
            )
          else if (records.isEmpty)
            const EmptyState(
              title: 'No records yet',
              message: 'Your mangrove scan history will appear here.',
              icon: Icons.history_rounded,
            )
          else
            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _RecordCard(record: record),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected ? AppColors.primaryDarkGreen : AppColors.white,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.primaryDarkGreen,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide.none,
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final ScanRecordModel record;

  @override
  Widget build(BuildContext context) {
    final date = record.capturedAt ?? record.createdAt;

    return SilvamangCard(
      onTap: () => context.pushNamed(
        RouteNames.recordDetail,
        pathParameters: {'id': record.id.toString()},
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.eco_rounded,
              color: AppColors.primaryDarkGreen,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.recordCode, style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  record.topScientificName,
                  style: AppTextStyles.titleMedium,
                ),
                Text(record.topCommonName, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    SilvamangBadge(
                      label: record.identificationStatus.isEmpty
                          ? 'Unknown'
                          : record.identificationStatus,
                      type: _statusBadge(record.identificationStatus),
                    ),
                    SilvamangBadge(
                      label: record.validationStatus.isEmpty
                          ? 'Unvalidated'
                          : record.validationStatus,
                      type: _statusBadge(record.validationStatus),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${record.confidence.toStringAsFixed(1)}% confidence',
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(record.locationName, style: AppTextStyles.bodySmall),
                Text(_dateLabel(date), style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
        ],
      ),
    );
  }
}

SilvamangBadgeType _statusBadge(String status) {
  final value = status.toLowerCase();
  if (value.contains('pending') || value.contains('review')) {
    return SilvamangBadgeType.warning;
  }
  if (value.contains('mismatch') || value.contains('failed')) {
    return SilvamangBadgeType.danger;
  }
  if (value.contains('match') ||
      value.contains('completed') ||
      value.contains('identified')) {
    return SilvamangBadgeType.success;
  }
  return SilvamangBadgeType.neutral;
}

String _dateLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
