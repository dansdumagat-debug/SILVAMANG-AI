import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/prediction_tile.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../controllers/records_controller.dart';

class RecordDetailPage extends ConsumerStatefulWidget {
  const RecordDetailPage({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends ConsumerState<RecordDetailPage> {
  int get _recordId => int.tryParse(widget.recordId) ?? 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(recordsControllerProvider.notifier)
          .loadRecordById(_recordId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordsControllerProvider);
    final record = state.selectedRecord;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Record Details')),
      body: state.isLoading
          ? const LoadingView(message: 'Loading record details...')
          : state.errorMessage != null
          ? Padding(
              padding: const EdgeInsets.all(AppConstants.screenPadding),
              child: SilvamangCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load record',
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
                          .loadRecordById(_recordId),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
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
                      Text(
                        record?.recordCode ?? '',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        record?.topScientificName.isNotEmpty == true
                            ? record!.topScientificName
                            : 'Unknown species',
                        style: AppTextStyles.titleLarge,
                      ),
                      Text(
                        record?.topCommonName.isNotEmpty == true
                            ? record!.topCommonName
                            : 'Common name not specified',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          SilvamangBadge(
                            label: record?.identificationStatus ?? 'Unknown',
                            type: _statusBadge(
                              record?.identificationStatus ?? '',
                            ),
                          ),
                          SilvamangBadge(
                            label: record?.validationStatus ?? 'Unvalidated',
                            type: _statusBadge(record?.validationStatus ?? ''),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DetailRow(
                        label: 'Confidence',
                        value:
                            '${(record?.confidence ?? 0).toStringAsFixed(1)}%',
                      ),
                      _DetailRow(
                        label: 'Capture Mode',
                        value: record?.captureMode ?? '',
                      ),
                      _DetailRow(
                        label: 'Validation',
                        value: record?.validationStatus ?? '',
                      ),
                    ],
                  ),
                ),
                if (state.successMessage != null) ...[
                  const SizedBox(height: AppSpacing.lg),
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
                const SectionHeader(title: 'Location'),
                const SizedBox(height: AppSpacing.md),
                SilvamangCard(
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Latitude',
                        value: record?.latitude?.toStringAsFixed(6) ?? '',
                      ),
                      _DetailRow(
                        label: 'Longitude',
                        value: record?.longitude?.toStringAsFixed(6) ?? '',
                      ),
                      _DetailRow(
                        label: 'Location',
                        value: record?.locationName ?? '',
                      ),
                      _DetailRow(
                        label: 'Address',
                        value: record?.address ?? '',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Top-K Predictions'),
                const SizedBox(height: AppSpacing.md),
                if ((record?.predictions ?? const []).isEmpty)
                  SilvamangCard(
                    child: Text(
                      'No prediction data available.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  )
                else
                  ...record!.predictions.map(
                    (prediction) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: PredictionTile(
                        rank: prediction.rank,
                        scientificName: prediction.scientificName,
                        commonName: prediction.commonName,
                        confidence: prediction.confidence,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Captured Images'),
                const SizedBox(height: AppSpacing.md),
                if ((record?.images ?? const []).isEmpty)
                  SilvamangCard(
                    child: Text(
                      'No uploaded images for this record.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  )
                else
                  ...record!.images.map(
                    (image) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SilvamangCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (image.imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppConstants.cardRadius),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: image.imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 180,
                                    color: AppColors.softGreen,
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      _ImagePlaceholder(text: image.imagePath),
                                ),
                              )
                            else
                              _ImagePlaceholder(text: image.imagePath),
                            Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                children: [
                                  _DetailRow(
                                    label: 'Plant Part',
                                    value: _plantPartLabel(image.plantPart),
                                  ),
                                  _DetailRow(
                                    label: 'Filename',
                                    value: image.originalFilename,
                                  ),
                                  _DetailRow(
                                    label: 'File Size',
                                    value: _formatBytes(image.fileSize),
                                  ),
                                  _DetailRow(
                                    label: 'Dimensions',
                                    value:
                                        image.width == null ||
                                            image.height == null
                                        ? ''
                                        : '${image.width} x ${image.height}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Measurement'),
                const SizedBox(height: AppSpacing.md),
                if (record?.measurement == null)
                  SilvamangCard(
                    child: Text(
                      'No measurement attached to this record.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  )
                else
                  SilvamangCard(
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Height',
                          value:
                              '${record!.measurement!.heightM.toStringAsFixed(1)} m',
                        ),
                        _DetailRow(
                          label: 'Canopy Width',
                          value:
                              '${record.measurement!.canopyWidthM.toStringAsFixed(1)} m',
                        ),
                        _DetailRow(
                          label: 'DBH',
                          value: record.measurement!.dbhCm == null
                              ? ''
                              : '${record.measurement!.dbhCm!.toStringAsFixed(1)} cm',
                        ),
                        _DetailRow(
                          label: 'Method',
                          value: record.measurement!.method,
                        ),
                        _DetailRow(
                          label: 'Confidence',
                          value:
                              '${record.measurement!.confidence.toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(title: 'Location Validation'),
                const SizedBox(height: AppSpacing.md),
                if (record?.locationValidation == null)
                  SilvamangCard(
                    child: Text(
                      'No location validation attached to this record.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  )
                else
                  SilvamangCard(
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Result',
                          value: record!.locationValidation!.result,
                        ),
                        _DetailRow(
                          label: 'Latitude',
                          value: record.locationValidation!.latitude
                              .toStringAsFixed(6),
                        ),
                        _DetailRow(
                          label: 'Longitude',
                          value: record.locationValidation!.longitude
                              .toStringAsFixed(6),
                        ),
                        _DetailRow(
                          label: 'Distance',
                          value:
                              record
                                      .locationValidation!
                                      .distanceToKnownDistributionKm ==
                                  null
                              ? ''
                              : '${record.locationValidation!.distanceToKnownDistributionKm!.toStringAsFixed(2)} km',
                        ),
                        _DetailRow(
                          label: 'Message',
                          value: record.locationValidation!.message,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                SilvamangButton(
                  text: 'Revalidate Location',
                  icon: Icons.my_location_rounded,
                  type: SilvamangButtonType.outline,
                  isLoading: state.isRevalidating,
                  onPressed: record == null || state.isRevalidating
                      ? null
                      : () => ref
                            .read(recordsControllerProvider.notifier)
                            .revalidateSelectedRecord(),
                ),
                const SizedBox(height: AppSpacing.xl),
                SilvamangButton(
                  text: 'Ask AI Assistant',
                  icon: Icons.chat_bubble_rounded,
                  onPressed: () => context.goNamed(RouteNames.aiAssistant),
                ),
              ],
            ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      color: AppColors.softGreen,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_rounded,
            color: AppColors.primaryGreen,
            size: 42,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text.isEmpty ? 'Image preview unavailable' : text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not specified' : value,
              style: AppTextStyles.labelLarge,
            ),
          ),
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

String _plantPartLabel(String plantPart) {
  return switch (plantPart) {
    'leaves' => 'Leaves',
    'bark' => 'Bark',
    'roots' => 'Roots',
    'flowers' => 'Flowers',
    'canopy' => 'Canopy',
    'full_tree' => 'Full Tree',
    'other' => 'Other',
    _ => 'Image',
  };
}

String _formatBytes(int bytes) {
  if (bytes <= 0) {
    return '';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
