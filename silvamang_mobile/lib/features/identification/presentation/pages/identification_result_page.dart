import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../../core/widgets/prediction_tile.dart';
import '../../../capture/presentation/controllers/capture_controller.dart';
import '../../../location_validation/presentation/controllers/location_controller.dart';
import '../controllers/identification_controller.dart';

class IdentificationResultPage extends ConsumerStatefulWidget {
  const IdentificationResultPage({super.key});

  @override
  ConsumerState<IdentificationResultPage> createState() =>
      _IdentificationResultPageState();
}

class _IdentificationResultPageState
    extends ConsumerState<IdentificationResultPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      ref.read(identificationControllerProvider.notifier).clearMessages();
      await ref.read(locationControllerProvider.notifier).loadCurrentLocation();
      final locationState = ref.read(locationControllerProvider);
      final captureState = ref.read(captureControllerProvider);
      await ref
          .read(identificationControllerProvider.notifier)
          .runMockPrediction(
            capturedImages: captureState.capturedImages,
            latitude: locationState.latitude,
            longitude: locationState.longitude,
            locationName: locationState.locationName,
            address: locationState.address,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identificationControllerProvider);
    final result = state.result;
    final predictionResponse = state.predictionResponse;
    final captureState = ref.watch(captureControllerProvider);
    final locationState = ref.watch(locationControllerProvider);
    final selectedImage = captureState.capturedImages.isEmpty
        ? null
        : captureState.capturedImages.first;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        title: const Text('Identification Result'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share_rounded),
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
          SilvamangCard(
            padding: EdgeInsets.zero,
            child: selectedImage == null
                ? Container(
                    height: 210,
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(
                        AppConstants.cardRadius,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            Icons.image_search_rounded,
                            color: AppColors.primaryGreen.withValues(
                              alpha: 0.55,
                            ),
                            size: 72,
                          ),
                        ),
                        Positioned(
                          left: AppSpacing.md,
                          bottom: AppSpacing.md,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('Photo preview placeholder'),
                          ),
                        ),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppConstants.cardRadius,
                    ),
                    child: Stack(
                      children: [
                        Image.memory(
                          selectedImage.previewBytes,
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          left: AppSpacing.md,
                          bottom: AppSpacing.md,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Image selected for mock analysis',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (selectedImage != null) ...[
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_plantPartLabel(selectedImage.plantPart)} selected for mock analysis',
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: captureState.capturedImages.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final image = captureState.capturedImages[index];
                        return Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                image.previewBytes,
                                width: 54,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _plantPartLabel(image.plantPart),
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SilvamangBadge(
                      label: predictionResponse?.mode ?? 'mock',
                      type: SilvamangBadgeType.info,
                    ),
                    const Spacer(),
                    if (state.isPredicting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  state.isPredicting
                      ? 'Analyzing selected mangrove images...'
                      : 'Mock AI analysis ready',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  predictionResponse == null
                      ? 'Using local mock classifier until the backend response is available.'
                      : '${predictionResponse.model.name} v${predictionResponse.model.version}',
                  style: AppTextStyles.bodyMedium,
                ),
                if (predictionResponse != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Received ${predictionResponse.received.imageCount} image(s): ${predictionResponse.received.plantParts.isEmpty ? 'No plant parts sent' : predictionResponse.received.plantParts.map(_plantPartLabel).join(', ')}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (state.warningMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Text(
                state.warningMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.warningOrange,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SilvamangBadge(
                  label: 'Identified',
                  type: SilvamangBadgeType.success,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(result.scientificName, style: AppTextStyles.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(result.commonName, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${result.confidence.toStringAsFixed(1)}% confidence',
                  style: AppTextStyles.labelLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Top-K Predictions'),
          const SizedBox(height: AppSpacing.md),
          ...result.predictions.map(
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
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Confidence Score'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${result.confidence.toStringAsFixed(1)}%',
                      style: AppTextStyles.metricValue,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const SilvamangBadge(
                      label: 'High',
                      type: SilvamangBadgeType.success,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: result.confidence / 100,
                    minHeight: 10,
                    color: AppColors.primaryGreen,
                    backgroundColor: AppColors.borderSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'AI Explanation'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Text(
              result.explanation.isEmpty
                  ? 'Mock AI explanation is not available yet.'
                  : result.explanation,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Mock AI Measurement Estimate'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              children: [
                _LocationRow(
                  label: 'Height',
                  value: '${result.heightM.toStringAsFixed(1)} m',
                ),
                _LocationRow(
                  label: 'Canopy',
                  value: '${result.canopyWidthM.toStringAsFixed(1)} m',
                ),
                _LocationRow(
                  label: 'Confidence',
                  value: '${result.measurementConfidence.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
          if (predictionResponse != null) ...[
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Location Hint'),
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Column(
                children: [
                  _LocationRow(
                    label: 'Latitude',
                    value:
                        predictionResponse.locationHint.latitude
                            ?.toStringAsFixed(6) ??
                        '',
                  ),
                  _LocationRow(
                    label: 'Longitude',
                    value:
                        predictionResponse.locationHint.longitude
                            ?.toStringAsFixed(6) ??
                        '',
                  ),
                  _LocationRow(
                    label: 'Message',
                    value: predictionResponse.locationHint.message,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Current Location'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SilvamangBadge(
                      label: locationState.isUsingFallback ? 'Fallback' : 'GPS',
                      type: locationState.isUsingFallback
                          ? SilvamangBadgeType.warning
                          : SilvamangBadgeType.success,
                    ),
                    const Spacer(),
                    if (locationState.isLoading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _LocationRow(
                  label: 'Latitude',
                  value: locationState.latitude?.toStringAsFixed(6) ?? '',
                ),
                _LocationRow(
                  label: 'Longitude',
                  value: locationState.longitude?.toStringAsFixed(6) ?? '',
                ),
                _LocationRow(
                  label: 'Location',
                  value: locationState.locationName,
                ),
                _LocationRow(label: 'Address', value: locationState.address),
                if (locationState.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    locationState.errorMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warningOrange,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SilvamangButton(
                  text: 'Refresh Location',
                  icon: Icons.my_location_rounded,
                  type: SilvamangButtonType.outline,
                  isLoading: locationState.isLoading,
                  onPressed: () => ref
                      .read(locationControllerProvider.notifier)
                      .loadCurrentLocation(),
                ),
              ],
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.lg),
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
            const SizedBox(height: AppSpacing.lg),
            SilvamangCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.successMessage!, style: AppTextStyles.titleMedium),
                  if (state.savedRecord?.recordCode.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Record code: ${state.savedRecord!.recordCode}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Uploaded images: ${state.uploadedImagesCount}',
                    style: AppTextStyles.bodyMedium,
                  ),
                  if (state.savedRecord?.locationValidation != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Validation: ${state.savedRecord!.locationValidation!.result}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                  if (state.warningMessage != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      state.warningMessage!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warningOrange,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: SilvamangButton(
                  text: 'View Details',
                  type: SilvamangButtonType.outline,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SilvamangButton(
                  text: 'Save Record',
                  isLoading: state.isSaving,
                  onPressed: state.isSaving
                      ? null
                      : () => ref
                            .read(identificationControllerProvider.notifier)
                            .saveCurrentResult(
                              capturedImages: captureState.capturedImages,
                              latitude: locationState.latitude,
                              longitude: locationState.longitude,
                              locationName: locationState.locationName,
                              address: locationState.address,
                              isUsingFallback: locationState.isUsingFallback,
                            ),
                ),
              ),
            ],
          ),
          if (state.successMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SilvamangButton(
              text: 'View Records',
              icon: Icons.history_rounded,
              type: SilvamangButtonType.outline,
              onPressed: () => context.goNamed(RouteNames.records),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => context.goNamed(RouteNames.measurement),
            icon: const Icon(Icons.straighten_rounded),
            label: const Text('Continue to Measurement'),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not available' : value,
              style: AppTextStyles.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
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
