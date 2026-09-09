import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../../core/widgets/prediction_tile.dart';
import '../../../../shared/models/prediction_model.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../../../capture/presentation/controllers/capture_controller.dart';
import '../../../location_validation/presentation/controllers/location_controller.dart';
import '../../../map/data/services/offline_map_cache_service.dart';
import '../../../measurement/presentation/controllers/field_distance_controller.dart';
import '../../../measurements/data/models/camera_measurement_result.dart';
import '../../../measurements/presentation/controllers/camera_measurement_controller.dart';
import '../../../species_database/data/models/external_species_observation_model.dart';
import '../../../species_database/data/repositories/external_species_observation_repository.dart';
import '../../../species_database/presentation/widgets/external_biodiversity_references_section.dart';
import '../../data/models/mock_ai_prediction_response.dart';
import '../../data/models/mock_identification_result.dart';
import '../../data/models/species_education_model.dart';
import '../../data/repositories/species_education_repository.dart';
import '../controllers/identification_controller.dart';

class IdentificationResultPage extends ConsumerStatefulWidget {
  const IdentificationResultPage({super.key});

  @override
  ConsumerState<IdentificationResultPage> createState() =>
      _IdentificationResultPageState();
}

class _IdentificationResultPageState
    extends ConsumerState<IdentificationResultPage> {
  final TextEditingController _manualBarangayController =
      TextEditingController();
  Future<SpeciesEducationModel>? _educationFuture;
  Future<ExternalSpeciesReferenceResult>? _externalReferencesFuture;
  String? _educationKey;
  String? _externalReferencesKey;

  @override
  void initState() {
    super.initState();
    Future.microtask(_runPrediction);
  }

  @override
  void dispose() {
    _manualBarangayController.dispose();
    super.dispose();
  }

  Future<void> _runPrediction() async {
    ref.read(identificationControllerProvider.notifier).clearMessages();
    await ref.read(locationControllerProvider.notifier).captureScanLocation();
    final locationState = ref.read(locationControllerProvider);
    final captureState = ref.read(captureControllerProvider);
    final fieldDistance = ref.read(fieldDistanceControllerProvider).measurement;
    await ref
        .read(identificationControllerProvider.notifier)
        .runMockPrediction(
          capturedImages: captureState.capturedImages,
          latitude: locationState.hasLocation ? locationState.latitude : null,
          longitude: locationState.hasLocation ? locationState.longitude : null,
          locationName: locationState.hasLocation
              ? locationState.locationName
              : null,
          address: locationState.hasLocation ? locationState.address : null,
          barangay: locationState.hasLocation ? locationState.barangay : null,
          fieldDistanceMeasurement: fieldDistance.hasDistance
              ? fieldDistance
              : null,
        );
  }

  Future<SpeciesEducationModel> _educationForSpecies(String scientificName) {
    final key = SpeciesEducationModel.normalizedKey(scientificName);
    if (_educationFuture == null || _educationKey != key) {
      _educationKey = key;
      _educationFuture = SpeciesEducationRepository.instance
          .findByScientificName(scientificName);
    }

    return _educationFuture!;
  }

  Future<ExternalSpeciesReferenceResult> _externalReferencesForPrediction(
    MockTopPrediction prediction,
  ) {
    final speciesName = prediction.scientificName.replaceAll('_', ' ').trim();
    final key = '${prediction.speciesId ?? 0}:$speciesName';
    if (_externalReferencesFuture == null || _externalReferencesKey != key) {
      _externalReferencesKey = key;
      _externalReferencesFuture = ref
          .read(externalSpeciesObservationRepositoryProvider)
          .getReferences(
            speciesId: prediction.speciesId,
            speciesName: speciesName,
          );
    }

    return _externalReferencesFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identificationControllerProvider);
    final cameraMeasurementSelection = ref.watch(
      cameraMeasurementSelectionProvider,
    );
    final result = _resultWithManualMeasurements(
      state.result,
      cameraMeasurementSelection,
    );
    final predictionResponse = state.predictionResponse;
    final captureState = ref.watch(captureControllerProvider);
    final locationState = ref.watch(locationControllerProvider);
    final fieldDistanceState = ref.watch(fieldDistanceControllerProvider);
    final fieldDistance = fieldDistanceState.measurement;
    final selectedImage = captureState.capturedImages.isEmpty
        ? null
        : captureState.capturedImages.first;
    final hasValidAiResult = _hasValidAiPrediction(predictionResponse);
    final validPredictions = hasValidAiResult
        ? predictionResponse!.validPredictions
        : const <PredictionModel>[];
    final topPrediction = predictionResponse?.topPrediction;
    final confidence = topPrediction == null
        ? null
        : _validConfidenceOrNull(topPrediction.confidence);
    final hasMeasurementEstimate = _hasValidMeasurementEstimate(result);
    final educationFuture = hasValidAiResult && topPrediction != null
        ? _educationForSpecies(topPrediction.scientificName)
        : null;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(
          fallbackRouteName: RouteNames.captureGuide,
        ),
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
                            child: const Text('Image selected for AI analysis'),
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
                    '${_plantPartLabel(selectedImage.plantPart)} selected for AI analysis',
                    style: AppTextStyles.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: captureState.capturedImages
                        .map(
                          (image) => Chip(
                            avatar: const Icon(Icons.eco_rounded, size: 16),
                            label: Text(_plantPartLabel(image.plantPart)),
                            backgroundColor: AppColors.softGreen,
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
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
                      label: state.errorMessage != null
                          ? 'Failed'
                          : _predictionBadgeLabel(predictionResponse),
                      type: state.errorMessage != null
                          ? SilvamangBadgeType.warning
                          : _predictionBadgeType(predictionResponse),
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
                      : state.errorMessage != null
                      ? state.offlineModeEnabled
                            ? 'Offline prediction failed.'
                            : 'Prediction failed.'
                      : _predictionTitle(predictionResponse),
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  state.errorMessage != null
                      ? state.errorMessage!
                      : predictionResponse == null
                      ? 'Select or capture a mangrove image to start AI identification.'
                      : '${predictionResponse.model.name} v${predictionResponse.model.version}',
                  style: AppTextStyles.bodyMedium,
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  SilvamangButton(
                    text: 'Retry Prediction',
                    icon: Icons.refresh_rounded,
                    type: SilvamangButtonType.outline,
                    onPressed: state.isPredicting ? null : _runPrediction,
                  ),
                ],
                if (predictionResponse != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _predictionDescription(predictionResponse),
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Mode: ${_modeLabel(predictionResponse.mode)}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Source: ${_sourceLabel(predictionResponse.source)}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Image Count: ${predictionResponse.received.imageCount} | Plant Parts: ${predictionResponse.received.plantParts.isEmpty ? 'No plant parts sent' : predictionResponse.received.plantParts.map(_plantPartLabel).join(', ')}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    value: state.offlineModeEnabled,
                    onChanged: state.isPredicting
                        ? null
                        : (enabled) async {
                            ref
                                .read(identificationControllerProvider.notifier)
                                .setOfflineMode(enabled);
                            await _runPrediction();
                          },
                    title: Text(
                      'Use Offline Model',
                      style: AppTextStyles.labelLarge,
                    ),
                    subtitle: Text(
                      'Skip server and identify on this Android phone.',
                      style: AppTextStyles.bodySmall,
                    ),
                    activeThumbColor: AppColors.primaryGreen,
                  ),
                ),
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
          if (hasValidAiResult && educationFuture != null) ...[
            FutureBuilder<SpeciesEducationModel>(
              future: educationFuture,
              builder: (context, snapshot) {
                final education =
                    snapshot.data ??
                    SpeciesEducationModel.fallback(
                      topPrediction!.scientificName,
                    );

                return _EducationalResultSection(
                  selectedImage: selectedImage,
                  education: education,
                  topPrediction: topPrediction!,
                  confidence: confidence,
                  predictionResponse: predictionResponse!,
                  hasLocation: locationState.hasLocation,
                  locationMessage: locationState.hasLocation
                      ? 'This species is commonly found in your area.'
                      : 'Location validation data is not available.',
                  onAskQuestion: (prompt) => _openEducationAssistant(
                    context,
                    prompt,
                    state.savedRecord?.id,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            ExternalBiodiversityReferencesSection(
              referencesFuture: _externalReferencesForPrediction(
                topPrediction!,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(title: 'Technical AI Details'),
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top-K Predictions', style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  ...validPredictions.map(
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
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    result.explanation.isEmpty
                        ? 'AI explanation is not available yet.'
                        : result.explanation,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            if (hasMeasurementEstimate) ...[
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: 'Measurement Estimate'),
              const SizedBox(height: AppSpacing.md),
              SilvamangCard(
                child: Column(
                  children: [
                    if (_hasValidMeasurementValue(result.heightM))
                      _LocationRow(
                        label: 'Height',
                        value: '${result.heightM.toStringAsFixed(1)} m',
                      ),
                    if (_hasValidMeasurementValue(result.canopyWidthM))
                      _LocationRow(
                        label: 'Canopy',
                        value: '${result.canopyWidthM.toStringAsFixed(1)} m',
                      ),
                    if (_hasValidNullableMeasurementValue(result.dbhCm))
                      _LocationRow(
                        label: 'DBH',
                        value: '${result.dbhCm!.toStringAsFixed(1)} cm',
                      ),
                    if (_hasValidConfidence(result.measurementConfidence))
                      _LocationRow(
                        label: 'Confidence',
                        value:
                            '${result.measurementConfidence.toStringAsFixed(1)}%',
                      ),
                  ],
                ),
              ),
            ],
          ] else ...[
            SilvamangCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warningOrange,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      state.errorMessage != null && selectedImage != null
                          ? 'No valid AI prediction result was produced. Check the failure reason above, then retry.'
                          : 'No valid AI prediction result. Please capture or select an image and try again.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (predictionResponse != null && hasValidAiResult) ...[
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
          const SectionHeader(title: 'Field Distance'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.social_distance_rounded,
                        color: AppColors.primaryDarkGreen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Estimated distance',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _LocationRow(
                  label: 'Distance',
                  value: fieldDistance.distanceMeters == null
                      ? ''
                      : '${fieldDistance.distanceMeters!.toStringAsFixed(2)} meters',
                ),
                _LocationRow(
                  label: 'Source',
                  value: _distanceSourceLabel(fieldDistance.distanceSource),
                ),
                _LocationRow(
                  label: 'Reliability',
                  value: fieldDistance.distanceReliability,
                ),
                _LocationRow(label: 'Status', value: fieldDistance.status),
                if (fieldDistance.warningMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    fieldDistance.warningMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warningOrange,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SilvamangButton(
                  text: fieldDistance.hasDistance
                      ? 'Remeasure Distance'
                      : 'Measure Distance First',
                  icon: Icons.directions_walk_rounded,
                  type: SilvamangButtonType.outline,
                  onPressed: () => context.pushNamed(RouteNames.fieldDistance),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Scan Location'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.primaryDarkGreen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Scan Location',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    SilvamangBadge(
                      label: locationState.hasLocation
                          ? 'Location captured'
                          : 'Location unavailable',
                      type: locationState.hasLocation
                          ? SilvamangBadgeType.success
                          : SilvamangBadgeType.warning,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _ScanLocationMapPreview(
                  latitude: locationState.latitude,
                  longitude: locationState.longitude,
                ),
                const SizedBox(height: AppSpacing.md),
                _LocationRow(
                  label: 'Status',
                  value: locationState.statusMessage,
                ),
                _LocationRow(
                  label: 'Latitude',
                  value: locationState.latitude?.toStringAsFixed(6) ?? '',
                ),
                _LocationRow(
                  label: 'Longitude',
                  value: locationState.longitude?.toStringAsFixed(6) ?? '',
                ),
                _LocationRow(
                  label: 'Accuracy',
                  value: locationState.accuracy == null
                      ? ''
                      : '${locationState.accuracy!.toStringAsFixed(1)} meters',
                ),
                _LocationRow(
                  label: 'Barangay',
                  value: locationState.barangay ?? 'Not available',
                ),
                _LocationRow(
                  label: 'Lookup',
                  value: locationState.barangayStatus,
                ),
                _LocationRow(
                  label: 'Source',
                  value: _locationSourceLabel(locationState.barangaySource),
                ),
                _LocationRow(
                  label: 'Manual barangay',
                  value: locationState.manualBarangay == null
                      ? 'Not available'
                      : '${locationState.manualBarangay} (manually entered, not GPS-verified)',
                ),
                _LocationRow(
                  label: 'Captured at',
                  value: locationState.timestamp == null
                      ? ''
                      : DateFormat(
                          'MMM d, yyyy h:mm a',
                        ).format(locationState.timestamp!),
                ),
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
                if (locationState.barangay == null) ...[
                  TextField(
                    controller: _manualBarangayController,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) => ref
                        .read(locationControllerProvider.notifier)
                        .setManualBarangay(value),
                    decoration: const InputDecoration(
                      labelText: 'Add Barangay Manually',
                      hintText: 'Type barangay name if verified in the field',
                      prefixIcon: Icon(Icons.edit_location_alt_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Manual barangay is a field note and is not GPS-verified.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warningOrange,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Row(
                  children: [
                    if (locationState.hasLocation) ...[
                      Expanded(
                        child: SilvamangButton(
                          text: 'Open in Maps',
                          icon: Icons.map_rounded,
                          type: SilvamangButtonType.outline,
                          onPressed: () => _openInMaps(
                            context,
                            locationState.latitude!,
                            locationState.longitude!,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: SilvamangButton(
                        text: 'Refresh Location',
                        icon: Icons.my_location_rounded,
                        type: SilvamangButtonType.outline,
                        isLoading: locationState.isLoading,
                        onPressed: () => ref
                            .read(locationControllerProvider.notifier)
                            .captureScanLocation(),
                      ),
                    ),
                  ],
                ),
                if (locationState.hasLocation) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SilvamangButton(
                    text: 'View Species Pin on Map',
                    icon: Icons.location_on_rounded,
                    type: SilvamangButtonType.outline,
                    onPressed: () => context.pushNamed(RouteNames.map),
                  ),
                ],
                if (locationState.isLoading) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(minHeight: 3),
                ],
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
                  text: 'Save Observation',
                  icon: Icons.save_rounded,
                  isLoading: state.isSaving,
                  onPressed: state.isSaving || !hasValidAiResult
                      ? null
                      : () => ref
                            .read(identificationControllerProvider.notifier)
                            .saveCurrentResult(
                              capturedImages: captureState.capturedImages,
                              latitude: locationState.hasLocation
                                  ? locationState.latitude
                                  : null,
                              longitude: locationState.hasLocation
                                  ? locationState.longitude
                                  : null,
                              locationName: locationState.hasLocation
                                  ? locationState.locationName
                                  : null,
                              address: locationState.hasLocation
                                  ? locationState.address
                                  : null,
                              barangay: locationState.hasLocation
                                  ? locationState.barangay
                                  : null,
                              manualBarangay: locationState.manualBarangay,
                              locationAccuracy: locationState.hasLocation
                                  ? locationState.accuracy
                                  : null,
                              locationCapturedAt: locationState.hasLocation
                                  ? locationState.timestamp
                                  : null,
                              barangayStatus: locationState.barangayStatus,
                              locationSource:
                                  locationState.barangay == null &&
                                      locationState.manualBarangay
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                  ? 'manual_barangay'
                                  : locationState.barangaySource,
                              fieldDistanceMeasurement:
                                  fieldDistance.hasDistance
                                  ? fieldDistance
                                  : null,
                              cameraMeasurementSelection:
                                  cameraMeasurementSelection,
                              isUsingFallback: false,
                            ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SilvamangButton(
                  text: 'Scan Again',
                  icon: Icons.camera_alt_rounded,
                  type: SilvamangButtonType.outline,
                  onPressed: () => context.pushNamed(RouteNames.captureGuide),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SilvamangButton(
            text: 'Ask AI Assistant',
            icon: Icons.chat_bubble_rounded,
            type: SilvamangButtonType.outline,
            onPressed: hasValidAiResult && topPrediction != null
                ? () => context.pushNamed(
                    RouteNames.aiAssistant,
                    queryParameters: {
                      'prompt': _assistantPromptForSpecies(topPrediction),
                      if (state.savedRecord != null)
                        'scan_record_id': state.savedRecord!.id.toString(),
                    },
                  )
                : null,
          ),
          if (state.successMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SilvamangButton(
              text: 'View Records',
              icon: Icons.history_rounded,
              type: SilvamangButtonType.outline,
              onPressed: () => context.pushNamed(RouteNames.records),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => context.pushNamed(
              RouteNames.measurement,
              extra: _preferredMeasurementImage(captureState.capturedImages),
            ),
            icon: const Icon(Icons.straighten_rounded),
            label: const Text('Continue to Measurement'),
          ),
        ],
      ),
    );
  }
}

class _EducationalResultSection extends StatelessWidget {
  const _EducationalResultSection({
    required this.selectedImage,
    required this.education,
    required this.topPrediction,
    required this.confidence,
    required this.predictionResponse,
    required this.hasLocation,
    required this.locationMessage,
    required this.onAskQuestion,
  });

  final CapturedPlantPartImage? selectedImage;
  final SpeciesEducationModel education;
  final MockTopPrediction topPrediction;
  final double? confidence;
  final MockAiPredictionResponse predictionResponse;
  final bool hasLocation;
  final String locationMessage;
  final ValueChanged<String> onAskQuestion;

  @override
  Widget build(BuildContext context) {
    final displayName = education.displayName.isNotEmpty
        ? education.displayName
        : topPrediction.scientificName.replaceAll('_', ' ');
    final commonName = education.commonName.isNotEmpty
        ? education.commonName
        : topPrediction.commonName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EducationalHeroCard(
          selectedImage: selectedImage,
          displayName: displayName,
          commonName: commonName,
          confidence: confidence,
          sourceLabel: _sourceLabel(predictionResponse.source),
          hasLocation: hasLocation,
        ),
        const SizedBox(height: AppSpacing.lg),
        _HabitatDistributionCard(education: education),
        const SizedBox(height: AppSpacing.lg),
        _AboutSpeciesCard(education: education, displayName: displayName),
        const SizedBox(height: AppSpacing.lg),
        _SpeciesInformationCard(
          education: education,
          displayName: displayName,
          commonName: commonName,
        ),
        const SizedBox(height: AppSpacing.lg),
        _EducationBulletCard(
          title: 'Ecological Importance',
          icon: Icons.waves_rounded,
          items: education.ecologicalImportance,
          fallback:
              'Mangroves protect shorelines, reduce erosion, support marine biodiversity, and store blue carbon.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _EducationTextCard(
          title: 'Mangrove History',
          icon: Icons.history_edu_rounded,
          text: education.history,
          fallback:
              'Mangroves were known and used by coastal communities for centuries before formal scientific study documented their ecological value.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _EducationTextCard(
          title: 'Discovery and Scientific Study',
          icon: Icons.science_rounded,
          text: education.scientificStudy,
          fallback:
              'Mangroves were not discovered by one person. Early communities recognized them, and scientists later documented their species diversity, taxonomy, and ecosystem functions.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _EducationBulletCard(
          title: 'Conservation and Protection',
          icon: Icons.volunteer_activism_rounded,
          items: education.conservationInformation,
          fallback:
              'Protect mangroves by reducing cutting, pollution, blocked tidal flow, and poorly planned coastal development.',
        ),
        const SizedBox(height: AppSpacing.lg),
        _TriviaSection(trivia: education.trivia),
        const SizedBox(height: AppSpacing.lg),
        _LearningFeatureCards(education: education),
        const SizedBox(height: AppSpacing.lg),
        _EducationReferencesCard(references: education.references),
        const SizedBox(height: AppSpacing.lg),
        _EducationAskAiCard(
          displayName: displayName,
          onAskQuestion: onAskQuestion,
        ),
        const SizedBox(height: AppSpacing.lg),
        _EducationLocationValidationCard(
          message: locationMessage,
          hint: education.locationValidationHint,
          hasLocation: hasLocation,
        ),
      ],
    );
  }
}

class _EducationalHeroCard extends StatelessWidget {
  const _EducationalHeroCard({
    required this.selectedImage,
    required this.displayName,
    required this.commonName,
    required this.confidence,
    required this.sourceLabel,
    required this.hasLocation,
  });

  final CapturedPlantPartImage? selectedImage;
  final String displayName;
  final String commonName;
  final double? confidence;
  final String sourceLabel;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    final confidenceValue = confidence == null
        ? null
        : (confidence! / 100).clamp(0.0, 1.0).toDouble();

    return SilvamangCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: SizedBox(
          height: 332,
          child: Stack(
            children: [
              Positioned.fill(
                child: selectedImage == null
                    ? CustomPaint(painter: _MangroveHeaderPainter())
                    : Image.memory(
                        selectedImage!.previewBytes,
                        fit: BoxFit.cover,
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primaryDarkGreen.withValues(alpha: 0.68),
                        AppColors.primaryDarkGreen.withValues(alpha: 0.16),
                        AppColors.primaryDarkGreen.withValues(alpha: 0.78),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.lg,
                child: Row(
                  children: [
                    const Icon(Icons.eco_rounded, color: AppColors.white),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'SILVAMANG AI',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.location_pin,
                      color: AppColors.white.withValues(alpha: 0.92),
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasLocation ? 'Your Location' : 'Location Pending',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(displayName, style: AppTextStyles.titleLarge),
                      if (commonName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(commonName, style: AppTextStyles.bodySmall),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          if (confidence != null) ...[
                            Text(
                              '${confidence!.toStringAsFixed(1)}% Confidence',
                              style: AppTextStyles.labelLarge,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: confidenceValue,
                                  minHeight: 10,
                                  color: AppColors.successGreen,
                                  backgroundColor: AppColors.borderSoft,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ] else
                            const Spacer(),
                          const SilvamangBadge(
                            label: 'AI Prediction',
                            type: SilvamangBadgeType.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Source: $sourceLabel',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitatDistributionCard extends StatelessWidget {
  const _HabitatDistributionCard({required this.education});

  final SpeciesEducationModel education;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final map = Container(
            height: 132,
            width: constraints.maxWidth < 360 ? double.infinity : 132,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(18),
            ),
            child: CustomPaint(painter: _DistributionMapPainter()),
          );

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Habitat & Distribution', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _IconLine(
                icon: Icons.public_rounded,
                text: education.distribution.isEmpty
                    ? 'Distribution information is not available.'
                    : education.distribution.join(', '),
              ),
              const SizedBox(height: AppSpacing.sm),
              _IconLine(
                icon: Icons.place_rounded,
                text: education.habitat.isEmpty
                    ? 'Habitat information is not available.'
                    : 'Found in: ${education.habitat.join(', ')}',
              ),
            ],
          );

          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                map,
                const SizedBox(height: AppSpacing.md),
                details,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              map,
              const SizedBox(width: AppSpacing.md),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}

class _AboutSpeciesCard extends StatelessWidget {
  const _AboutSpeciesCard({required this.education, required this.displayName});

  final SpeciesEducationModel education;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About This Species', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            education.description.isEmpty
                ? 'Educational information is not available for this species yet.'
                : education.description,
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.volunteer_activism_rounded,
                  color: AppColors.primaryDarkGreen,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    education.conservationNote.isEmpty
                        ? '$displayName should be verified by field experts for research use.'
                        : education.conservationNote,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryDarkGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesInformationCard extends StatelessWidget {
  const _SpeciesInformationCard({
    required this.education,
    required this.displayName,
    required this.commonName,
  });

  final SpeciesEducationModel education;
  final String displayName;
  final String commonName;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Species Information', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _EducationInfoRow(
            icon: Icons.local_florist_rounded,
            label: 'Scientific Name',
            value: displayName,
          ),
          _EducationInfoRow(
            icon: Icons.badge_rounded,
            label: 'Common Name',
            value: commonName.isEmpty ? 'Not available' : commonName,
          ),
          _EducationInfoRow(
            icon: Icons.account_tree_rounded,
            label: 'Family',
            value: education.family.isEmpty
                ? 'Not available'
                : education.family,
          ),
          if (education.leafCharacteristics.isNotEmpty)
            _EducationInfoRow(
              icon: Icons.eco_rounded,
              label: 'Leaves',
              value: education.leafCharacteristics,
            ),
          if (education.rootCharacteristics.isNotEmpty)
            _EducationInfoRow(
              icon: Icons.forest_rounded,
              label: 'Roots',
              value: education.rootCharacteristics,
            ),
          if (education.physicalCharacteristics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...education.physicalCharacteristics.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _IconLine(icon: Icons.check_rounded, text: item),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EducationInfoRow extends StatelessWidget {
  const _EducationInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 112,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primaryDarkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EducationBulletCard extends StatelessWidget {
  const _EducationBulletCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.fallback,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.isEmpty ? [fallback] : items;

    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primaryDarkGreen),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...visibleItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _IconLine(icon: Icons.check_circle_rounded, text: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _EducationTextCard extends StatelessWidget {
  const _EducationTextCard({
    required this.title,
    required this.icon,
    required this.text,
    required this.fallback,
  });

  final String title;
  final IconData icon;
  final String text;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(text.isEmpty ? fallback : text, style: AppTextStyles.bodyLarge),
        ],
      ),
    );
  }
}

class _TriviaSection extends StatelessWidget {
  const _TriviaSection({required this.trivia});

  final List<String> trivia;

  @override
  Widget build(BuildContext context) {
    final items = trivia.isEmpty
        ? const ['Educational trivia is not available for this species yet.']
        : trivia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryDarkGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Did You Know?',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 142,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              return _TriviaCard(
                text: items[index],
                icon: _triviaIcon(index),
                color: _triviaColor(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TriviaCard extends StatelessWidget {
  const _TriviaCard({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 154,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textDark),
          ),
        ],
      ),
    );
  }
}

class _EducationReferencesCard extends StatelessWidget {
  const _EducationReferencesCard({required this.references});

  final List<String> references;

  @override
  Widget build(BuildContext context) {
    final visibleReferences = references.isEmpty
        ? const ['References are not available for this species yet.']
        : references;

    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('References', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...visibleReferences.map(
            (reference) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _IconLine(icon: Icons.menu_book_rounded, text: reference),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningFeatureCards extends StatelessWidget {
  const _LearningFeatureCards({required this.education});

  final SpeciesEducationModel education;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        label: 'Did You Know?',
        icon: Icons.lightbulb_rounded,
        text: education.trivia.isEmpty
            ? 'Mangroves can store large amounts of carbon in roots and soil.'
            : education.trivia.first,
      ),
      (
        label: 'Ecological Fact',
        icon: Icons.waves_rounded,
        text: education.ecologicalImportance.isEmpty
            ? 'Mangroves reduce wave energy and help prevent erosion.'
            : education.ecologicalImportance.first,
      ),
      (
        label: 'Identification Tip',
        icon: Icons.search_rounded,
        text: education.rootCharacteristics.isEmpty
            ? 'Check roots, leaves, bark, flowers, propagules, and habitat together.'
            : education.rootCharacteristics,
      ),
      (
        label: 'Conservation Tip',
        icon: Icons.shield_rounded,
        text: education.conservationInformation.isEmpty
            ? 'Protect tidal flow and avoid clearing mangrove stands.'
            : education.conservationInformation.first,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Learning Cards', style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = cards[index];

              return Container(
                width: 176,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                  border: Border.all(color: AppColors.borderSoft),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, color: AppColors.primaryGreen),
                    const SizedBox(height: AppSpacing.sm),
                    Text(item.label, style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        item.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EducationAskAiCard extends StatelessWidget {
  const _EducationAskAiCard({
    required this.displayName,
    required this.onAskQuestion,
  });

  final String displayName;
  final ValueChanged<String> onAskQuestion;

  @override
  Widget build(BuildContext context) {
    final prompts = [
      (
        label: 'Why roots matter?',
        prompt: 'Why are the roots of $displayName important?',
      ),
      (
        label: 'Ecosystem role',
        prompt: 'How does $displayName help the mangrove ecosystem?',
      ),
      (label: 'Where found?', prompt: 'Where is $displayName commonly found?'),
    ];

    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_rounded,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Ask AI', style: AppTextStyles.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: prompts
                .map(
                  (item) => ActionChip(
                    avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(item.label),
                    backgroundColor: AppColors.softGreen,
                    side: BorderSide.none,
                    onPressed: () => onAskQuestion(item.prompt),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _EducationLocationValidationCard extends StatelessWidget {
  const _EducationLocationValidationCard({
    required this.message,
    required this.hint,
    required this.hasLocation,
  });

  final String message;
  final String hint;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    final isCommon = hint.trim().toLowerCase() == 'commonly_found';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.successGreen],
        ),
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Location Validation',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasLocation && isCommon
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  color: hasLocation && isCommon
                      ? AppColors.successGreen
                      : AppColors.warningOrange,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryDarkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
      ],
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

class _MangroveHeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primaryDarkGreen, AppColors.primaryGreen],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final waterPaint = Paint()
      ..color = AppColors.softBlue.withValues(alpha: 0.34)
      ..style = PaintingStyle.fill;
    final waterPath = Path()
      ..moveTo(0, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.58,
        size.width * 0.5,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.84,
        size.width,
        size.height * 0.66,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    final rootPaint = Paint()
      ..color = const Color(0xFFB9A27A).withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final x = size.width * (0.08 + i * 0.09);
      canvas.drawLine(
        Offset(x, size.height * 0.36),
        Offset(x - 24, size.height * 0.66),
        rootPaint,
      );
      canvas.drawLine(
        Offset(x, size.height * 0.36),
        Offset(x + 22, size.height * 0.66),
        rootPaint,
      );
    }

    final leafPaint = Paint()
      ..color = AppColors.successGreen.withValues(alpha: 0.42);
    for (var i = 0; i < 18; i++) {
      final x = size.width * ((i * 37) % 100) / 100;
      final y = size.height * (0.12 + ((i * 19) % 24) / 100);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 42, height: 18),
        leafPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DistributionMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final waterPaint = Paint()..color = const Color(0xFFB9E1E4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      waterPaint,
    );

    final landPaint = Paint()..color = const Color(0xFF8DBD72);
    final coastPaint = Paint()
      ..color = AppColors.primaryGreen.withValues(alpha: 0.38)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final landOne = Path()
      ..moveTo(size.width * 0.12, size.height * 0.14)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.08,
        size.width * 0.48,
        size.height * 0.34,
      )
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.58,
        size.width * 0.14,
        size.height * 0.48,
      )
      ..close();
    canvas.drawPath(landOne, landPaint);
    canvas.drawPath(landOne, coastPaint);

    final landTwo = Path()
      ..moveTo(size.width * 0.58, size.height * 0.24)
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.18,
        size.width * 0.86,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.74,
        size.width * 0.54,
        size.height * 0.54,
      )
      ..close();
    canvas.drawPath(landTwo, landPaint);
    canvas.drawPath(landTwo, coastPaint);

    final pinPaint = Paint()..color = AppColors.primaryDarkGreen;
    canvas.drawCircle(
      Offset(size.width * 0.58, size.height * 0.48),
      7,
      pinPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.58, size.height * 0.48),
      3,
      Paint()..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLocationMapPreview extends StatelessWidget {
  const _ScanLocationMapPreview({this.latitude, this.longitude});

  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final hasLocation = latitude != null && longitude != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 168,
        width: double.infinity,
        child: hasLocation
            ? FlutterMap(
                options: MapOptions(
                  initialCenter: latlong.LatLng(latitude!, longitude!),
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: OfflineMapCacheService.tileUrlTemplate,
                    userAgentPackageName:
                        OfflineMapCacheService.userAgentPackageName,
                  ),
                  TileLayer(
                    urlTemplate: OfflineMapCacheService.labelTileUrlTemplate,
                    userAgentPackageName:
                        OfflineMapCacheService.userAgentPackageName,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: latlong.LatLng(latitude!, longitude!),
                        width: 46,
                        height: 46,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDarkGreen.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: AppColors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Container(
                color: AppColors.softGreen,
                child: Center(
                  child: Icon(
                    Icons.location_off_rounded,
                    color: Colors.grey.shade600,
                    size: 38,
                  ),
                ),
              ),
      ),
    );
  }
}

Future<void> _openInMaps(
  BuildContext context,
  double latitude,
  double longitude,
) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open maps.')));
  }
}

void _openEducationAssistant(
  BuildContext context,
  String prompt,
  String? scanRecordId,
) {
  context.pushNamed(
    RouteNames.aiAssistant,
    queryParameters: {
      'prompt': prompt,
      if (scanRecordId != null && scanRecordId.isNotEmpty)
        'scan_record_id': scanRecordId,
    },
  );
}

String _plantPartLabel(String plantPart) {
  return switch (plantPart) {
    'leaves' => 'Leaves',
    'bark' => 'Bark',
    'roots' => 'Roots',
    'flowers' => 'Flowers',
    'fruits' => 'Fruits',
    'canopy' => 'Canopy',
    'full_tree' => 'Full Tree',
    'other' => 'Other',
    _ => 'Image',
  };
}

String _predictionBadgeLabel(dynamic predictionResponse) {
  if (predictionResponse == null) {
    return 'Waiting';
  }
  return _isCnnMode(predictionResponse.mode)
      ? _modeLabel(predictionResponse.mode)
      : 'Mock Fallback';
}

SilvamangBadgeType _predictionBadgeType(dynamic predictionResponse) {
  if (predictionResponse == null) {
    return SilvamangBadgeType.warning;
  }
  return _isCnnMode(predictionResponse.mode)
      ? SilvamangBadgeType.success
      : SilvamangBadgeType.warning;
}

String _predictionTitle(dynamic predictionResponse) {
  if (predictionResponse == null) {
    return 'Waiting for selected image';
  }
  return _isCnnMode(predictionResponse.mode)
      ? '${_modeLabel(predictionResponse.mode)} prediction ready'
      : 'Mock fallback prediction ready';
}

String _predictionDescription(dynamic predictionResponse) {
  if (predictionResponse == null) {
    return 'Select or capture a mangrove image to start AI identification.';
  }
  return _isCnnMode(predictionResponse.mode)
      ? 'Prediction generated using the trained EfficientNet CNN model.'
      : predictionResponse.warning ?? 'Prototype fallback prediction was used.';
}

bool _hasValidAiPrediction(MockAiPredictionResponse? response) {
  return response?.isValidCnnResult ?? false;
}

bool _isCnnMode(String mode) {
  final normalizedMode = mode.trim().toLowerCase();
  return normalizedMode == 'cnn_baseline' ||
      normalizedMode == 'cnn_efficientnet_b0' ||
      normalizedMode == 'offline_onnx_efficientnet_b0';
}

String _modeLabel(String mode) {
  return switch (mode.trim().toLowerCase()) {
    'cnn_efficientnet_b0' => 'CNN EfficientNet-B0',
    'cnn_baseline' => 'CNN Baseline',
    'offline_onnx_efficientnet_b0' => 'Offline EfficientNet-B0',
    'mock' => 'Mock Fallback',
    'fallback' => 'Mock Fallback',
    _ => _cleanLabel(mode),
  };
}

String _sourceLabel(String source) {
  return switch (source.trim().toLowerCase()) {
    'python_ai_service' => 'Python AI Service',
    'flutter_offline_model' => 'On-device Flutter model',
    'mock_fallback' => 'Mock Fallback',
    _ => _cleanLabel(source),
  };
}

String _locationSourceLabel(String? source) {
  final normalized = source?.trim().toLowerCase();
  return switch (normalized) {
    'online_location' => 'Online location',
    'offline_geojson' => 'Offline barangay boundary',
    'offline_downloaded_boundary' => 'Offline downloaded boundary',
    'gps_low_accuracy' => 'GPS accuracy too low',
    'manual_barangay' => 'Manual barangay',
    'location_unavailable' => 'Location unavailable',
    'offline_geojson_missing' => 'Boundary file missing',
    'offline_geojson_empty' => 'Boundary data unavailable',
    'offline_geojson_invalid' => 'Boundary data invalid',
    'offline_geojson_error' => 'Boundary lookup error',
    'unavailable' || '' || null => 'Not available',
    _ => _cleanLabel(source!),
  };
}

String _distanceSourceLabel(String source) {
  return switch (source) {
    'gps_walk_measurement' => 'GPS walk measurement',
    'manual_input' => 'Manual input',
    _ => 'Unavailable',
  };
}

IconData _triviaIcon(int index) {
  return switch (index % 4) {
    0 => Icons.waves_rounded,
    1 => Icons.eco_rounded,
    2 => Icons.set_meal_rounded,
    _ => Icons.forest_rounded,
  };
}

Color _triviaColor(int index) {
  return switch (index % 4) {
    0 => const Color(0xFF2D8FB7),
    1 => AppColors.successGreen,
    2 => const Color(0xFF3D7FA6),
    _ => AppColors.primaryGreen,
  };
}

CapturedPlantPartImage? _preferredMeasurementImage(
  List<CapturedPlantPartImage> images,
) {
  for (final preferredPart in const ['full_tree', 'canopy']) {
    for (final image in images) {
      if (image.plantPart == preferredPart) {
        return image;
      }
    }
  }

  return images.isEmpty ? null : images.first;
}

bool _hasValidConfidence(double confidence) {
  return confidence.isFinite;
}

String _assistantPromptForSpecies(MockTopPrediction prediction) {
  final scientificName = prediction.scientificName.replaceAll('_', ' ').trim();
  final commonName = prediction.commonName.trim();
  final name = commonName.isEmpty
      ? scientificName
      : '$scientificName ($commonName)';

  return 'The identified species is $name. Explain its habitat, ecological importance, and conservation value.';
}

bool _hasValidMeasurementEstimate(MockIdentificationResult result) {
  return _hasValidMeasurementValue(result.heightM) ||
      _hasValidMeasurementValue(result.canopyWidthM) ||
      _hasValidNullableMeasurementValue(result.dbhCm);
}

MockIdentificationResult _resultWithManualMeasurements(
  MockIdentificationResult result,
  CameraMeasurementSelection cameraMeasurementSelection,
) {
  final heightResult = cameraMeasurementSelection.heightResult;
  final canopyResult = cameraMeasurementSelection.canopyWidthResult;
  if (!_isUsableManualMeasurement(heightResult) &&
      !_isUsableManualMeasurement(canopyResult)) {
    return result;
  }

  return result.copyWith(
    heightM: _isUsableManualMeasurement(heightResult)
        ? heightResult!.estimatedValueM
        : result.heightM,
    canopyWidthM: _isUsableManualMeasurement(canopyResult)
        ? canopyResult!.estimatedValueM
        : result.canopyWidthM,
    measurementMethod: _manualMeasurementMethod(
      heightResult,
      canopyResult,
      result.measurementMethod,
    ),
    measurementConfidence: _manualMeasurementConfidence(
      heightResult,
      canopyResult,
      result.measurementConfidence,
    ),
    explanation: result.explanation.isEmpty
        ? 'Manual measurement attached.'
        : '${result.explanation} Manual measurement attached.',
  );
}

bool _isUsableManualMeasurement(CameraMeasurementResult? result) {
  return result != null &&
      result.estimatedValueM.isFinite &&
      result.estimatedValueM > 0;
}

String _manualMeasurementMethod(
  CameraMeasurementResult? heightResult,
  CameraMeasurementResult? canopyResult,
  String fallback,
) {
  final heightMethod = _isUsableManualMeasurement(heightResult)
      ? heightResult!.methodUsed
      : null;
  final canopyMethod = _isUsableManualMeasurement(canopyResult)
      ? canopyResult!.methodUsed
      : null;
  if (heightMethod != null && canopyMethod != null) {
    return heightMethod == canopyMethod ? heightMethod : 'manual_mixed';
  }

  return heightMethod ?? canopyMethod ?? fallback;
}

double _manualMeasurementConfidence(
  CameraMeasurementResult? heightResult,
  CameraMeasurementResult? canopyResult,
  double fallback,
) {
  final values = [
    if (_isUsableManualMeasurement(heightResult))
      _confidenceFromManualReliability(heightResult!),
    if (_isUsableManualMeasurement(canopyResult))
      _confidenceFromManualReliability(canopyResult!),
  ];
  if (values.isEmpty) {
    return fallback;
  }

  return values.reduce((total, value) => total + value) / values.length;
}

double _confidenceFromManualReliability(CameraMeasurementResult result) {
  if (result.methodUsed == 'calibrated_reference_object') {
    return 92;
  }

  if (result.distanceSource == 'manual_input') {
    return 88;
  }

  if (result.distanceSource == 'gps_walk_measurement') {
    return 74;
  }

  return 60;
}

bool _hasValidMeasurementValue(double value) {
  return value.isFinite && value > 0;
}

bool _hasValidNullableMeasurementValue(double? value) {
  return value != null && _hasValidMeasurementValue(value);
}

double? _validConfidenceOrNull(double confidence) {
  return _hasValidConfidence(confidence) ? confidence : null;
}

String _cleanLabel(String value) {
  final label = value.replaceAll('_', ' ').trim();
  if (label.isEmpty) {
    return 'Not available';
  }

  return label
      .split(' ')
      .map((word) {
        if (word.isEmpty) {
          return word;
        }
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}
