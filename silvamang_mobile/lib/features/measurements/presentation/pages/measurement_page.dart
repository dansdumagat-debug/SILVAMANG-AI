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
import '../../../measurement/data/models/field_distance_measurement.dart';
import '../../../measurement/presentation/controllers/field_distance_controller.dart';
import '../../data/models/camera_measurement_result.dart';
import '../controllers/camera_measurement_controller.dart';

enum _MeasurementType { height, canopy }

class MeasurementPage extends ConsumerStatefulWidget {
  const MeasurementPage({super.key});

  @override
  ConsumerState<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends ConsumerState<MeasurementPage> {
  _MeasurementType _type = _MeasurementType.height;

  Future<void> _openCameraMeasurement() async {
    final result = await context.pushNamed<CameraMeasurementResult>(
      RouteNames.cameraPointingMeasurement,
      queryParameters: {
        'type': _type == _MeasurementType.height
            ? 'tree_height'
            : 'canopy_width',
      },
    );
    if (!mounted || result == null) return;
    useCameraMeasurementResult(ref, result);
  }

  @override
  Widget build(BuildContext context) {
    final fieldDistance = ref
        .watch(fieldDistanceControllerProvider)
        .measurement;
    final cameraMeasurements = ref.watch(cameraMeasurementSelectionProvider);
    final cameraResult = _type == _MeasurementType.height
        ? cameraMeasurements.heightResult
        : cameraMeasurements.canopyWidthResult;

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
                  'Choose a measurement, then point the live camera at the tree. '
                  'The app uses your field or manually entered distance with the '
                  'camera angle to estimate the size.',
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
                        onTap: () =>
                            setState(() => _type = _MeasurementType.height),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _MeasurementTypeButton(
                        label: 'Canopy Width',
                        icon: Icons.width_wide_rounded,
                        isSelected: _type == _MeasurementType.canopy,
                        onTap: () =>
                            setState(() => _type = _MeasurementType.canopy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                SilvamangButton(
                  text: 'Start Camera Measurement',
                  icon: Icons.center_focus_strong_rounded,
                  onPressed: _openCameraMeasurement,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _FieldDistanceCard(
            measurement: fieldDistance,
            onMeasure: () => context.pushNamed(RouteNames.fieldDistance),
          ),
          if (cameraResult != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _CameraMeasurementSummaryCard(result: cameraResult),
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

class _FieldDistanceCard extends StatelessWidget {
  const _FieldDistanceCard({
    required this.measurement,
    required this.onMeasure,
  });

  final FieldDistanceMeasurement measurement;
  final VoidCallback onMeasure;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Field Distance', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            measurement.hasDistance
                ? 'Distance from standing point: '
                      '${measurement.distanceMeters!.toStringAsFixed(2)} m'
                : 'No field distance recorded. You can enter a measured '
                      'distance on the camera screen.',
            style: AppTextStyles.bodyMedium,
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
                : 'Measure Field Distance',
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

class _CameraMeasurementSummaryCard extends StatelessWidget {
  const _CameraMeasurementSummaryCard({required this.result});

  final CameraMeasurementResult result;

  @override
  Widget build(BuildContext context) {
    final isHeight = result.measurementType == 'tree_height';
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Camera Measurement Result', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          MetricCard(
            title: isHeight ? 'Estimated height' : 'Estimated canopy width',
            value: '${result.estimatedValueM.toStringAsFixed(2)} m',
            icon: isHeight ? Icons.height_rounded : Icons.width_wide_rounded,
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
