import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../../../capture/presentation/controllers/capture_controller.dart';
import '../../../measurement/data/models/field_distance_measurement.dart';
import '../../../measurement/presentation/controllers/field_distance_controller.dart';
import '../../data/models/camera_measurement_result.dart';
import '../controllers/camera_measurement_controller.dart';
import '../controllers/measurement_controller.dart';

enum _MeasurementType { height, canopy }

enum _MeasurementMode { cameraPointing, imageMarking }

enum _MarkingTarget { subject, reference }

class MeasurementPage extends ConsumerStatefulWidget {
  const MeasurementPage({super.key, this.initialImage});

  final CapturedPlantPartImage? initialImage;

  @override
  ConsumerState<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends ConsumerState<MeasurementPage> {
  final _distanceController = TextEditingController();
  final _referenceHeightController = TextEditingController(text: '1');
  final _referenceDistanceController = TextEditingController();
  final _notesController = TextEditingController();

  _MeasurementType _type = _MeasurementType.height;
  _MeasurementMode _mode = _MeasurementMode.imageMarking;
  _MarkingTarget _markingTarget = _MarkingTarget.subject;
  Offset? _firstPoint;
  Offset? _secondPoint;
  Offset? _referenceFirstPoint;
  Offset? _referenceSecondPoint;
  _PrototypeMeasurementResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _distanceController.addListener(_refreshDistanceInput);
    _referenceHeightController.addListener(_refreshDistanceInput);
    _referenceDistanceController.addListener(_refreshDistanceInput);
  }

  @override
  void dispose() {
    _distanceController.removeListener(_refreshDistanceInput);
    _referenceHeightController.removeListener(_refreshDistanceInput);
    _referenceDistanceController.removeListener(_refreshDistanceInput);
    _distanceController.dispose();
    _referenceHeightController.dispose();
    _referenceDistanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final captureState = ref.watch(captureControllerProvider);
    final fieldDistanceState = ref.watch(fieldDistanceControllerProvider);
    final aiMeasurementState = ref.watch(measurementControllerProvider);
    final fieldDistance = fieldDistanceState.measurement;
    final cameraMeasurementSelection = ref.watch(
      cameraMeasurementSelectionProvider,
    );
    final cameraMeasurementResult = cameraMeasurementSelection.latestResult;
    final measurementImage = _selectMeasurementImage(
      captureState.capturedImages,
      widget.initialImage,
      _type,
    );
    final imagePath = measurementImage?.imagePath.trim() ?? '';
    final hasMeasurementImage =
        imagePath.isNotEmpty && File(imagePath).existsSync();
    final shouldWarnAboutImage =
        measurementImage != null &&
        !_isRecommendedMeasurementPart(measurementImage.plantPart);
    final manualDistanceM = double.tryParse(_distanceController.text.trim());
    final referenceHeightM = double.tryParse(
      _referenceHeightController.text.trim(),
    );
    final hasDistanceInput =
        fieldDistance.hasDistance ||
        (manualDistanceM != null && manualDistanceM > 0);
    final hasReferenceHeight = referenceHeightM != null && referenceHeightM > 0;
    final hasReferenceMarks =
        _referenceFirstPoint != null && _referenceSecondPoint != null;
    final canCalculate =
        hasMeasurementImage &&
        _firstPoint != null &&
        _secondPoint != null &&
        hasReferenceMarks &&
        hasReferenceHeight &&
        !aiMeasurementState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('Measurements'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          const SectionHeader(title: 'Measurement Workflow'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose what you want to measure. Use Camera Pointing with a measured field distance, or Image Marking with a visible reference object.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _MeasurementTypeButton(
                        label: 'Tree Height',
                        icon: Icons.height_rounded,
                        isSelected: _type == _MeasurementType.height,
                        onTap: () => _selectType(_MeasurementType.height),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _MeasurementTypeButton(
                        label: 'Canopy Width',
                        icon: Icons.width_wide_rounded,
                        isSelected: _type == _MeasurementType.canopy,
                        onTap: () => _selectType(_MeasurementType.canopy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Measurement Mode', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _ModeButton(
                  label: 'Camera Pointing',
                  subtitle: 'Live camera base/top or left/right workflow',
                  icon: Icons.center_focus_strong_rounded,
                  isSelected: _mode == _MeasurementMode.cameraPointing,
                  onTap: _openCameraPointingMode,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ModeButton(
                  label: 'Image Marking Prototype',
                  subtitle: 'Use the captured scan image with distance input',
                  icon: Icons.image_search_rounded,
                  isSelected: _mode == _MeasurementMode.imageMarking,
                  onTap: () => _selectMode(_MeasurementMode.imageMarking),
                ),
                const SizedBox(height: AppSpacing.md),
                SilvamangButton(
                  text: 'Start Camera Measurement',
                  icon: Icons.center_focus_strong_rounded,
                  onPressed: _openCameraPointingMode,
                ),
              ],
            ),
          ),
          if (cameraMeasurementResult != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _CameraMeasurementSummaryCard(result: cameraMeasurementResult),
          ],
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Field Inputs', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _FieldDistanceInputSummary(
                  measurement: fieldDistance,
                  onMeasure: () => context.pushNamed(RouteNames.fieldDistance),
                ),
                const SizedBox(height: AppSpacing.md),
                _NumberField(
                  controller: _distanceController,
                  label: 'Phone-to-tree distance (meters, optional)',
                  hint: fieldDistance.hasDistance
                      ? 'Leave blank to use GPS walk distance'
                      : 'Distance from phone to mangrove, example: 5',
                  icon: Icons.social_distance_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                _NumberField(
                  controller: _referenceHeightController,
                  label: 'Reference object height (meters)',
                  hint: 'Example: 1 for a one-meter pole',
                  icon: Icons.straighten_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                _NumberField(
                  controller: _referenceDistanceController,
                  label: 'Reference object distance (meters, optional)',
                  hint: 'Leave blank when the reference is beside the tree',
                  icon: Icons.compare_arrows_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_markingTitle, style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(_markingSubtitle, style: AppTextStyles.bodyMedium),
                if (shouldWarnAboutImage) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'For height or canopy measurement, use a full tree/canopy image with the reference object visible.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warningOrange,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _MarkingTargetButton(
                        label: _type == _MeasurementType.height
                            ? 'Tree Span'
                            : 'Canopy Span',
                        icon: _type == _MeasurementType.height
                            ? Icons.height_rounded
                            : Icons.width_wide_rounded,
                        isSelected: _markingTarget == _MarkingTarget.subject,
                        onTap: () =>
                            _selectMarkingTarget(_MarkingTarget.subject),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MarkingTargetButton(
                        label: 'Reference',
                        icon: Icons.straighten_rounded,
                        isSelected: _markingTarget == _MarkingTarget.reference,
                        onTap: () =>
                            _selectMarkingTarget(_MarkingTarget.reference),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (!hasMeasurementImage)
                  Container(
                    height: 240,
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.softGreen,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Text(
                      'Measurement image unavailable. Please capture or select an image first.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  GestureDetector(
                    onTapUp: (details) => _recordPoint(details.localPosition),
                    child: AspectRatio(
                      aspectRatio: 1.35,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                File(imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: AppColors.softGreen,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Text(
                                    'Measurement image unavailable. Please capture or select an image first.',
                                    style: AppTextStyles.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              CustomPaint(
                                painter: _PointMarkingPainter(
                                  type: _type,
                                  activeTarget: _markingTarget,
                                  firstPoint: _firstPoint,
                                  secondPoint: _secondPoint,
                                  referenceFirstPoint: _referenceFirstPoint,
                                  referenceSecondPoint: _referenceSecondPoint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  !hasMeasurementImage
                      ? 'Capture or select an image before marking points.'
                      : _firstPoint == null || _secondPoint == null
                      ? 'Mark the measured span first.'
                      : !hasReferenceMarks
                      ? 'Mark the reference object top and bottom.'
                      : !hasReferenceHeight
                      ? 'Enter the real reference object height.'
                      : hasDistanceInput
                      ? 'Calibration ready. Distance will be saved with the estimate.'
                      : 'Calibration ready. Reference object is assumed beside the tree.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: SilvamangButton(
                        text: 'Reset Points',
                        icon: Icons.refresh_rounded,
                        type: SilvamangButtonType.outline,
                        onPressed: _resetPoints,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SilvamangButton(
                        text: aiMeasurementState.isLoading
                            ? 'Checking AI'
                            : 'Calculate',
                        icon: Icons.calculate_rounded,
                        onPressed: canCalculate
                            ? () => _calculatePrototype(
                                fieldDistance,
                                measurementImage,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.dangerRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_result == null)
            const _PrototypeWarningCard()
          else
            _PrototypeResultCard(
              result: _result!,
              onUseResult: () => _usePrototypeResult(_result!),
            ),
          if (aiMeasurementState.isLoading ||
              aiMeasurementState.measurement != null ||
              aiMeasurementState.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _AiMeasurementStatusCard(state: aiMeasurementState),
          ],
          const SizedBox(height: AppSpacing.xl),
          SilvamangButton(
            text: 'Continue to Location Validation',
            icon: Icons.location_on_rounded,
            onPressed: () => context.pushNamed(RouteNames.locationValidation),
          ),
        ],
      ),
    );
  }

  String get _markingTitle {
    return _type == _MeasurementType.height
        ? 'Calibrated Image Marking: Mark base and top'
        : 'Calibrated Image Marking: Mark left and right canopy edge';
  }

  String get _markingSubtitle {
    return _type == _MeasurementType.height
        ? 'Mark the tree span, then switch to Reference and mark a known object.'
        : 'Mark the canopy span, then switch to Reference and mark a known object.';
  }

  String _measurementTypeKey(_MeasurementType type) {
    return type == _MeasurementType.height ? 'tree_height' : 'canopy_width';
  }

  void _selectType(_MeasurementType type) {
    setState(() {
      _type = type;
      _firstPoint = null;
      _secondPoint = null;
      _referenceFirstPoint = null;
      _referenceSecondPoint = null;
      _result = null;
      _errorMessage = null;
    });
    ref.read(measurementControllerProvider.notifier).clearMeasurement();
  }

  void _selectMode(_MeasurementMode mode) {
    setState(() {
      _mode = mode;
      _result = null;
      _errorMessage = null;
    });
    ref.read(measurementControllerProvider.notifier).clearMeasurement();
  }

  void _selectMarkingTarget(_MarkingTarget target) {
    setState(() {
      _markingTarget = target;
      _result = null;
      _errorMessage = null;
    });
    clearCameraMeasurementSelectionType(ref, _measurementTypeKey(_type));
    ref.read(measurementControllerProvider.notifier).clearMeasurement();
  }

  Future<void> _openCameraPointingMode() async {
    setState(() => _mode = _MeasurementMode.cameraPointing);
    final result = await context.pushNamed<CameraMeasurementResult>(
      RouteNames.cameraPointingMeasurement,
      queryParameters: {
        'type': _type == _MeasurementType.height
            ? 'tree_height'
            : 'canopy_width',
      },
    );
    if (!mounted || result == null) {
      return;
    }
    useCameraMeasurementResult(ref, result);
  }

  void _recordPoint(Offset point) {
    setState(() {
      if (_markingTarget == _MarkingTarget.subject) {
        if (_firstPoint == null ||
            (_firstPoint != null && _secondPoint != null)) {
          _firstPoint = point;
          _secondPoint = null;
        } else {
          _secondPoint = point;
        }
      } else {
        if (_referenceFirstPoint == null ||
            (_referenceFirstPoint != null && _referenceSecondPoint != null)) {
          _referenceFirstPoint = point;
          _referenceSecondPoint = null;
        } else {
          _referenceSecondPoint = point;
        }
      }
      _result = null;
      _errorMessage = null;
    });
    clearCameraMeasurementSelectionType(ref, _measurementTypeKey(_type));
    ref.read(measurementControllerProvider.notifier).clearMeasurement();
  }

  void _resetPoints() {
    setState(() {
      _firstPoint = null;
      _secondPoint = null;
      _referenceFirstPoint = null;
      _referenceSecondPoint = null;
      _result = null;
      _errorMessage = null;
    });
    clearCameraMeasurementSelectionType(ref, _measurementTypeKey(_type));
    ref.read(measurementControllerProvider.notifier).clearMeasurement();
  }

  void _refreshDistanceInput() {
    if (!mounted) {
      return;
    }

    setState(() {
      _result = null;
      _errorMessage = null;
    });
    clearCameraMeasurementSelectionType(ref, _measurementTypeKey(_type));
    ref.read(measurementControllerProvider.notifier).clearMeasurement();
  }

  Future<void> _calculatePrototype(
    FieldDistanceMeasurement fieldDistance,
    CapturedPlantPartImage? measurementImage,
  ) async {
    final first = _firstPoint;
    final second = _secondPoint;
    final referenceFirst = _referenceFirstPoint;
    final referenceSecond = _referenceSecondPoint;
    final manualDistanceText = _distanceController.text.trim();
    final referenceHeightText = _referenceHeightController.text.trim();
    final referenceDistanceText = _referenceDistanceController.text.trim();
    final manualDistanceM = double.tryParse(manualDistanceText);
    final referenceHeightM = double.tryParse(referenceHeightText);
    final referenceDistanceM = double.tryParse(referenceDistanceText);
    final gpsDistanceM = fieldDistance.distanceMeters;
    final distanceM = manualDistanceM != null && manualDistanceM > 0
        ? manualDistanceM
        : gpsDistanceM != null && gpsDistanceM > 0
        ? gpsDistanceM
        : null;
    final distanceSource = manualDistanceM != null && manualDistanceM > 0
        ? 'manual_input'
        : gpsDistanceM != null && gpsDistanceM > 0
        ? 'gps_walk_measurement'
        : 'unavailable';

    if (measurementImage == null ||
        measurementImage.imagePath.trim().isEmpty ||
        !File(measurementImage.imagePath).existsSync()) {
      setState(() {
        _errorMessage =
            'Measurement image unavailable. Please capture or select an image first.';
      });
      return;
    }

    if (first == null || second == null) {
      setState(() {
        _errorMessage = 'Mark the measured tree or canopy span first.';
      });
      return;
    }

    if (referenceFirst == null || referenceSecond == null) {
      setState(() {
        _errorMessage = 'Mark the reference object top and bottom.';
      });
      return;
    }

    if (manualDistanceText.isNotEmpty &&
        (manualDistanceM == null || manualDistanceM <= 0)) {
      setState(() {
        _errorMessage = 'Enter a valid manual distance in meters.';
      });
      return;
    }

    if (referenceHeightText.isEmpty ||
        referenceHeightM == null ||
        referenceHeightM <= 0) {
      setState(() {
        _errorMessage = 'Enter the real reference object height in meters.';
      });
      return;
    }

    if (referenceDistanceText.isNotEmpty &&
        (referenceDistanceM == null || referenceDistanceM <= 0)) {
      setState(() {
        _errorMessage = 'Enter a valid reference object distance in meters.';
      });
      return;
    }

    if (referenceDistanceM != null &&
        referenceDistanceM > 0 &&
        (distanceM == null || distanceM <= 0)) {
      setState(() {
        _errorMessage =
            'Enter the phone-to-tree distance before using a separate reference distance.';
      });
      return;
    }

    final pixelDistance = (second - first).distance;
    final referencePixelDistance = (referenceSecond - referenceFirst).distance;
    if (pixelDistance <= 0) {
      setState(() {
        _errorMessage = 'The two measured-span points must be different.';
      });
      return;
    }

    if (referencePixelDistance <= 0) {
      setState(() {
        _errorMessage = 'The two reference-object points must be different.';
      });
      return;
    }

    final distanceRatio =
        distanceM != null && distanceM > 0 && referenceDistanceM != null
        ? distanceM / referenceDistanceM
        : 1.0;
    final metersPerPixel = referenceHeightM / referencePixelDistance;
    final estimateM = max(0.01, pixelDistance * metersPerPixel * distanceRatio);
    final confidence = _calibrationConfidence(
      subjectPixelDistance: pixelDistance,
      referencePixelDistance: referencePixelDistance,
      hasSubjectDistance: distanceM != null && distanceM > 0,
      hasReferenceDistance:
          referenceDistanceM != null && referenceDistanceM > 0,
    );

    final result = _PrototypeMeasurementResult(
      type: _type,
      estimateM: estimateM,
      pixelDistance: pixelDistance,
      referencePixelDistance: referencePixelDistance,
      referenceHeightM: referenceHeightM,
      referenceDistanceMeters: referenceDistanceM,
      distanceRatio: distanceRatio,
      confidence: confidence,
      method: 'calibrated_reference_object',
      notes: _notesController.text.trim(),
      fieldDistanceMeters: distanceM,
      distanceSource: distanceSource,
    );

    setState(() {
      _errorMessage = null;
      _result = result;
    });

    await ref
        .read(measurementControllerProvider.notifier)
        .loadMeasurement(
          capturedImages: [measurementImage],
          measurementType: _type == _MeasurementType.height
              ? 'tree_height'
              : 'canopy_width',
          referenceHeightM: referenceHeightM,
          subjectDistanceM: distanceM,
          referenceDistanceM: referenceDistanceM,
          subjectPixelSpan: pixelDistance,
          referencePixelSpan: referencePixelDistance,
        );
  }

  void _usePrototypeResult(_PrototypeMeasurementResult result) {
    useCameraMeasurementResult(
      ref,
      CameraMeasurementResult(
        measurementType: _measurementTypeKey(result.type),
        measurementMode: 'image_marking_calibrated',
        estimatedValueM: result.estimateM,
        methodUsed: 'calibrated_reference_object',
        distanceSource: result.distanceSource,
        distanceM: result.fieldDistanceMeters ?? 0,
        arSupported: false,
        arUsed: false,
        reliability: 'Calibrated reference',
        warningMessage: result.fieldDistanceMeters == null
            ? 'Reference object is assumed beside the measured tree.'
            : 'Accuracy depends on point placement and field distance.',
        createdAt: DateTime.now(),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${result.title} will be saved with the observation.'),
      ),
    );
  }

  double _calibrationConfidence({
    required double subjectPixelDistance,
    required double referencePixelDistance,
    required bool hasSubjectDistance,
    required bool hasReferenceDistance,
  }) {
    var confidence = 92.0;
    if (subjectPixelDistance < 40) {
      confidence -= 15;
    }
    if (referencePixelDistance < 30) {
      confidence -= 18;
    }
    if (!hasSubjectDistance) {
      confidence -= 5;
    }
    if (!hasReferenceDistance) {
      confidence -= 3;
    }

    return confidence.clamp(35.0, 95.0).toDouble();
  }
}

class _FieldDistanceInputSummary extends StatelessWidget {
  const _FieldDistanceInputSummary({
    required this.measurement,
    required this.onMeasure,
  });

  final FieldDistanceMeasurement measurement;
  final VoidCallback onMeasure;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            measurement.hasDistance
                ? 'Distance from standing point: ${measurement.distanceMeters!.toStringAsFixed(2)} m'
                : 'Distance not measured. You may enter distance manually.',
            style: AppTextStyles.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            measurement.hasDistance
                ? 'Source: GPS walk measurement'
                : 'Use Field Distance Meter before scanning for a GPS-based estimate.',
            style: AppTextStyles.bodySmall,
          ),
          if (measurement.warningMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              measurement.warningMessage!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warningOrange,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SilvamangButton(
            text: measurement.hasDistance
                ? 'Remeasure Distance'
                : 'Measure Distance First',
            icon: Icons.directions_walk_rounded,
            type: SilvamangButtonType.outline,
            fullWidth: false,
            onPressed: onMeasure,
          ),
        ],
      ),
    );
  }
}

class _PrototypeMeasurementResult {
  const _PrototypeMeasurementResult({
    required this.type,
    required this.estimateM,
    required this.pixelDistance,
    required this.referencePixelDistance,
    required this.referenceHeightM,
    required this.referenceDistanceMeters,
    required this.distanceRatio,
    required this.confidence,
    required this.method,
    required this.notes,
    required this.fieldDistanceMeters,
    required this.distanceSource,
  });

  final _MeasurementType type;
  final double estimateM;
  final double pixelDistance;
  final double referencePixelDistance;
  final double referenceHeightM;
  final double? referenceDistanceMeters;
  final double distanceRatio;
  final double confidence;
  final String method;
  final String notes;
  final double? fieldDistanceMeters;
  final String distanceSource;

  String get title =>
      type == _MeasurementType.height ? 'Tree Height' : 'Canopy Width';
}

class _MeasurementTypeButton extends StatelessWidget {
  const _MeasurementTypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : AppColors.softGreen,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderSoft,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.white : AppColors.primaryDarkGreen,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge.copyWith(
                color: isSelected ? AppColors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkingTargetButton extends StatelessWidget {
  const _MarkingTargetButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : AppColors.softGreen,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderSoft,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.white : AppColors.primaryDarkGreen,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isSelected ? AppColors.white : AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.softGreen : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryDarkGreen),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryGreen,
              ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _PrototypeResultCard extends StatelessWidget {
  const _PrototypeResultCard({required this.result, required this.onUseResult});

  final _PrototypeMeasurementResult result;
  final VoidCallback onUseResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Calibrated Result'),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: result.title,
                value: '${result.estimateM.toStringAsFixed(2)} m',
                icon: result.type == _MeasurementType.height
                    ? Icons.height_rounded
                    : Icons.width_wide_rounded,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MetricCard(
                title: 'Pixel Distance',
                value: '${result.pixelDistance.toStringAsFixed(1)} px',
                icon: Icons.timeline_rounded,
                color: AppColors.warningOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SilvamangCard(
          child: Column(
            children: [
              _DetailRow(label: 'Measurement type', value: result.title),
              _DetailRow(label: 'Method', value: result.method),
              _DetailRow(
                label: 'Marked distance',
                value: '${result.pixelDistance.toStringAsFixed(1)} px',
              ),
              _DetailRow(
                label: 'Reference height',
                value: '${result.referenceHeightM.toStringAsFixed(2)} m',
              ),
              _DetailRow(
                label: 'Reference span',
                value: '${result.referencePixelDistance.toStringAsFixed(1)} px',
              ),
              _DetailRow(
                label: 'Estimated distance',
                value: result.fieldDistanceMeters == null
                    ? 'Not available'
                    : '${result.fieldDistanceMeters!.toStringAsFixed(2)} m',
              ),
              _DetailRow(
                label: 'Reference distance',
                value: result.referenceDistanceMeters == null
                    ? 'Same as measured tree'
                    : '${result.referenceDistanceMeters!.toStringAsFixed(2)} m',
              ),
              _DetailRow(
                label: 'Confidence',
                value: '${result.confidence.toStringAsFixed(1)}%',
              ),
              _DetailRow(
                label: 'Distance source',
                value: _distanceSourceLabel(result.distanceSource),
              ),
              _DetailRow(
                label: 'Warning',
                value: result.fieldDistanceMeters == null
                    ? 'Reference object is assumed beside the measured tree.'
                    : 'Accuracy depends on point placement and field distance.',
              ),
              if (result.notes.isNotEmpty)
                _DetailRow(label: 'Notes', value: result.notes),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const _PrototypeWarningCard(),
        const SizedBox(height: AppSpacing.md),
        SilvamangButton(
          text: result.type == _MeasurementType.height
              ? 'Use for Height'
              : 'Use for Width',
          icon: Icons.check_circle_rounded,
          onPressed: onUseResult,
        ),
      ],
    );
  }
}

class _CameraMeasurementSummaryCard extends StatelessWidget {
  const _CameraMeasurementSummaryCard({required this.result});

  final CameraMeasurementResult result;

  @override
  Widget build(BuildContext context) {
    final title = result.measurementType == 'tree_height'
        ? 'Estimated height'
        : 'Estimated canopy width';

    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Camera Measurement Result', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          MetricCard(
            title: title,
            value: '${result.estimatedValueM.toStringAsFixed(2)} m',
            icon: result.measurementType == 'tree_height'
                ? Icons.height_rounded
                : Icons.width_wide_rounded,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailRow(label: 'Method', value: result.methodUsed),
          _DetailRow(
            label: 'Distance source',
            value: _distanceSourceLabel(result.distanceSource),
          ),
          _DetailRow(
            label: 'Distance',
            value: '${result.distanceM.toStringAsFixed(2)} m',
          ),
          _DetailRow(label: 'Reliability', value: result.reliability),
          _DetailRow(label: 'Warning', value: result.warningMessage),
        ],
      ),
    );
  }
}

class _AiMeasurementStatusCard extends StatelessWidget {
  const _AiMeasurementStatusCard({required this.state});

  final MeasurementState state;

  @override
  Widget build(BuildContext context) {
    final measurement = state.measurement;
    final hasValue =
        measurement?.heightM != null ||
        measurement?.canopyWidthM != null ||
        measurement?.dbhCm != null;

    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backend Calibration', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (state.isLoading)
            const LinearProgressIndicator()
          else if (state.errorMessage != null)
            Text(
              state.errorMessage!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.warningOrange,
              ),
            )
          else if (measurement != null && hasValue) ...[
            if (measurement.heightM != null)
              _DetailRow(
                label: 'AI height',
                value: '${measurement.heightM!.toStringAsFixed(2)} m',
              ),
            if (measurement.canopyWidthM != null)
              _DetailRow(
                label: 'AI canopy',
                value: '${measurement.canopyWidthM!.toStringAsFixed(2)} m',
              ),
            _DetailRow(label: 'Method', value: measurement.measurementMethod),
            _DetailRow(
              label: 'Confidence',
              value: '${measurement.confidence.toStringAsFixed(1)}%',
            ),
            if (measurement.warning != null)
              _DetailRow(label: 'Warning', value: measurement.warning!),
          ] else
            Text(
              'No backend measurement returned.',
              style: AppTextStyles.bodyMedium,
            ),
        ],
      ),
    );
  }
}

class _PrototypeWarningCard extends StatelessWidget {
  const _PrototypeWarningCard();

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primaryDarkGreen,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'For accurate image marking, place a known reference object beside the tree and mark both the subject span and reference span carefully.',
              style: AppTextStyles.bodyMedium,
            ),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: AppTextStyles.metricLabel),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

String _distanceSourceLabel(String source) {
  return switch (source) {
    'gps_walk_measurement' => 'GPS walk measurement',
    'manual_input' => 'Manual input',
    _ => 'Unavailable',
  };
}

CapturedPlantPartImage? _selectMeasurementImage(
  List<CapturedPlantPartImage> images,
  CapturedPlantPartImage? initialImage,
  _MeasurementType type,
) {
  CapturedPlantPartImage? findByParts(List<String> parts) {
    for (final part in parts) {
      for (final image in images) {
        if (image.plantPart == part) {
          return image;
        }
      }
    }
    return null;
  }

  final preferred = type == _MeasurementType.canopy
      ? findByParts(const ['canopy', 'full_tree'])
      : findByParts(const ['full_tree', 'canopy']);
  if (preferred != null) {
    return preferred;
  }

  if (initialImage != null) {
    return initialImage;
  }

  return images.isEmpty ? null : images.first;
}

bool _isRecommendedMeasurementPart(String plantPart) {
  return plantPart == 'canopy' || plantPart == 'full_tree';
}

class _PointMarkingPainter extends CustomPainter {
  const _PointMarkingPainter({
    required this.type,
    required this.activeTarget,
    required this.firstPoint,
    required this.secondPoint,
    required this.referenceFirstPoint,
    required this.referenceSecondPoint,
  });

  final _MeasurementType type;
  final _MarkingTarget activeTarget;
  final Offset? firstPoint;
  final Offset? secondPoint;
  final Offset? referenceFirstPoint;
  final Offset? referenceSecondPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final subjectLinePaint = Paint()
      ..color = AppColors.warningOrange
      ..strokeWidth = activeTarget == _MarkingTarget.subject ? 5 : 3
      ..strokeCap = StrokeCap.round;
    final referenceLinePaint = Paint()
      ..color = AppColors.softBlue
      ..strokeWidth = activeTarget == _MarkingTarget.reference ? 5 : 3
      ..strokeCap = StrokeCap.round;

    if (firstPoint != null && secondPoint != null) {
      canvas.drawLine(firstPoint!, secondPoint!, subjectLinePaint);
    }
    if (referenceFirstPoint != null && referenceSecondPoint != null) {
      canvas.drawLine(
        referenceFirstPoint!,
        referenceSecondPoint!,
        referenceLinePaint,
      );
    }
    _drawPoint(canvas, firstPoint, _firstPointLabel, AppColors.warningOrange);
    _drawPoint(canvas, secondPoint, _secondPointLabel, AppColors.warningOrange);
    _drawPoint(canvas, referenceFirstPoint, 'Ref A', AppColors.softBlue);
    _drawPoint(canvas, referenceSecondPoint, 'Ref B', AppColors.softBlue);
  }

  String get _firstPointLabel =>
      type == _MeasurementType.height ? 'Base' : 'Left';

  String get _secondPointLabel =>
      type == _MeasurementType.height ? 'Top' : 'Right';

  void _drawPoint(Canvas canvas, Offset? point, String label, Color color) {
    if (point == null) {
      return;
    }

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(point, 12, fill);
    canvas.drawCircle(point, 12, stroke);
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.primaryDarkGreen,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelOffset = Offset(
      point.dx - textPainter.width / 2,
      max(4, point.dy - 34),
    );
    final labelRect = Rect.fromLTWH(
      labelOffset.dx - 8,
      labelOffset.dy - 4,
      textPainter.width + 16,
      textPainter.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(999)),
      Paint()..color = AppColors.white.withValues(alpha: 0.92),
    );
    textPainter.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant _PointMarkingPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.activeTarget != activeTarget ||
        oldDelegate.firstPoint != firstPoint ||
        oldDelegate.secondPoint != secondPoint ||
        oldDelegate.referenceFirstPoint != referenceFirstPoint ||
        oldDelegate.referenceSecondPoint != referenceSecondPoint;
  }
}
