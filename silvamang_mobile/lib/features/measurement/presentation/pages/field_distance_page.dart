import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../data/models/field_distance_measurement.dart';
import '../controllers/field_distance_controller.dart';

class FieldDistancePage extends ConsumerWidget {
  const FieldDistancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fieldDistanceControllerProvider);
    final controller = ref.read(fieldDistanceControllerProvider.notifier);
    final measurement = state.measurement;
    final displayDistance =
        measurement.distanceMeters ?? state.liveDistanceMeters;
    final currentAccuracy = state.currentPoint?.accuracyM;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(
          fallbackRouteName: RouteNames.captureGuide,
        ),
        title: const Text('Field Distance Meter'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          const SectionHeader(title: 'Walk-to-Measure Distance'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Stand at your scan position.\n'
                  '2. Tap Set Standing Point.\n'
                  '3. Walk to the mangrove/front point.\n'
                  '4. Tap Set Target Point.\n'
                  '5. Use the measured distance for scan measurement.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Estimated distance is GPS-based and should be treated as a field estimate, not exact tape-measure accuracy.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warningOrange,
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
                Text('Estimated distance', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayDistance == null
                          ? '--'
                          : displayDistance.toStringAsFixed(2),
                      style: AppTextStyles.metricValue,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('m', style: AppTextStyles.labelLarge),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _FieldDistanceRow(
                  label: 'GPS accuracy',
                  value: currentAccuracy == null
                      ? 'Not available'
                      : '${currentAccuracy.toStringAsFixed(1)} m',
                ),
                _FieldDistanceRow(
                  label: 'Final distance',
                  value: measurement.distanceMeters == null
                      ? 'Not available'
                      : '${measurement.distanceMeters!.toStringAsFixed(2)} m',
                ),
                _FieldDistanceRow(
                  label: 'Reliability',
                  value: measurement.distanceReliability,
                ),
                _FieldDistanceRow(label: 'Status', value: measurement.status),
                if (measurement.warningMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    measurement.warningMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warningOrange,
                    ),
                  ),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.errorMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.dangerRed,
                    ),
                  ),
                ],
                if (state.successMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(state.successMessage!, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Field Path', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                AspectRatio(
                  aspectRatio: 1.9,
                  child: CustomPaint(
                    painter: _FieldDistancePathPainter(
                      hasStart: measurement.hasStart,
                      hasTarget: measurement.hasTarget,
                      hasCurrent: state.currentPoint != null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              children: [
                _PointDetails(
                  title: 'Standing Point',
                  point: measurement.startPoint,
                  status: _pointStatus(measurement.startPoint),
                ),
                const Divider(height: AppSpacing.lg),
                _PointDetails(
                  title: 'Target Point',
                  point: measurement.targetPoint,
                  status: _pointStatus(measurement.targetPoint),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: SilvamangButton(
                  text: 'Set Standing Point',
                  icon: Icons.my_location_rounded,
                  isLoading: state.isLoading && !measurement.hasStart,
                  onPressed: state.isLoading
                      ? null
                      : controller.setStandingPoint,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SilvamangButton(
                  text: 'Reset',
                  icon: Icons.refresh_rounded,
                  type: SilvamangButtonType.outline,
                  onPressed: controller.reset,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SilvamangButton(
            text: 'Set Target Point',
            icon: Icons.flag_rounded,
            type: SilvamangButtonType.outline,
            isLoading: state.isLoading && measurement.hasStart,
            onPressed: !measurement.hasStart || state.isLoading
                ? null
                : controller.setTargetPoint,
          ),
          const SizedBox(height: AppSpacing.sm),
          SilvamangButton(
            text: 'Use Distance for Scan',
            icon: Icons.check_circle_rounded,
            onPressed: !measurement.hasDistance
                ? null
                : () {
                    controller.useDistanceForScan();
                    SilvamangBackButton.goBack(
                      context,
                      fallbackRouteName: RouteNames.captureGuide,
                    );
                  },
          ),
        ],
      ),
    );
  }
}

class _PointDetails extends StatelessWidget {
  const _PointDetails({
    required this.title,
    required this.point,
    required this.status,
  });

  final String title;
  final FieldDistancePoint? point;
  final String status;

  @override
  Widget build(BuildContext context) {
    final timestamp = point?.timestamp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        _FieldDistanceRow(label: 'Status', value: status),
        _FieldDistanceRow(
          label: 'Latitude',
          value: point == null
              ? 'Not available'
              : point!.latitude.toStringAsFixed(6),
        ),
        _FieldDistanceRow(
          label: 'Longitude',
          value: point == null
              ? 'Not available'
              : point!.longitude.toStringAsFixed(6),
        ),
        _FieldDistanceRow(
          label: 'Accuracy',
          value: point == null
              ? 'Not available'
              : '${point!.accuracyM.toStringAsFixed(1)} m',
        ),
        _FieldDistanceRow(
          label: 'Best accuracy',
          value: point == null
              ? 'Not available'
              : '${point!.bestAccuracyM.toStringAsFixed(1)} m',
        ),
        _FieldDistanceRow(
          label: 'Avg accuracy',
          value: point == null
              ? 'Not available'
              : '${point!.averageAccuracyM.toStringAsFixed(1)} m',
        ),
        _FieldDistanceRow(
          label: 'Timestamp',
          value: timestamp == null
              ? 'Not available'
              : DateFormat('MMM d, yyyy h:mm a').format(timestamp),
        ),
      ],
    );
  }
}

class _FieldDistanceRow extends StatelessWidget {
  const _FieldDistanceRow({required this.label, required this.value});

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
            width: 112,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

String _pointStatus(FieldDistancePoint? point) {
  if (point == null) {
    return 'Not set';
  }
  if (point.accuracyM > 30) {
    return 'Poor';
  }
  if (point.accuracyM > 10) {
    return 'Fair';
  }
  return 'Good';
}

class _FieldDistancePathPainter extends CustomPainter {
  const _FieldDistancePathPainter({
    required this.hasStart,
    required this.hasTarget,
    required this.hasCurrent,
  });

  final bool hasStart;
  final bool hasTarget;
  final bool hasCurrent;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = AppColors.softGreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      background,
    );

    final linePaint = Paint()
      ..color = AppColors.primaryGreen.withValues(alpha: 0.36)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()..color = AppColors.primaryDarkGreen;
    final targetPaint = Paint()..color = AppColors.warningOrange;

    final start = Offset(size.width * 0.18, size.height * 0.68);
    final current = Offset(size.width * 0.5, size.height * 0.42);
    final target = Offset(size.width * 0.82, size.height * 0.28);

    canvas.drawLine(start, hasTarget ? target : current, linePaint);

    _drawPoint(canvas, start, pointPaint, hasStart ? 'Start' : 'Start');
    if (!hasTarget && hasCurrent) {
      _drawPoint(canvas, current, targetPaint, 'Now');
    }
    _drawPoint(canvas, target, targetPaint, hasTarget ? 'Target' : 'Target');
  }

  void _drawPoint(Canvas canvas, Offset point, Paint paint, String label) {
    canvas.drawCircle(point, 12, paint);
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.primaryDarkGreen,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, point + const Offset(-18, 18));
  }

  @override
  bool shouldRepaint(covariant _FieldDistancePathPainter oldDelegate) {
    return oldDelegate.hasStart != hasStart ||
        oldDelegate.hasTarget != hasTarget ||
        oldDelegate.hasCurrent != hasCurrent;
  }
}
