import 'dart:math' as math;

class MeasurementPositionGuidance {
  const MeasurementPositionGuidance({
    required this.isTooClose,
    required this.angleSpanDegrees,
    this.viewingAngleDegrees,
    this.recommendedDistanceM,
  });

  final bool isTooClose;
  final double angleSpanDegrees;
  final double? viewingAngleDegrees;
  final double? recommendedDistanceM;
}

class MeasurementGeometry {
  const MeasurementGeometry._();

  static const double maximumHeightViewingAngleDegrees = 65;
  static const double maximumHeightSpanDegrees = 75;
  static const double maximumExtendedHeightSpanDegrees = 130;
  static const double targetHeightViewingAngleDegrees = 55;
  static const double targetHeightSpanDegrees = 65;
  static const double maximumCanopySpanDegrees = 65;
  static const double targetCanopySpanDegrees = 50;

  static double heightFromAngularSpan({
    required double distanceM,
    required double cameraHeightM,
    required double angleSpanRadians,
  }) {
    if (!_isPositive(distanceM) ||
        !_isPositive(cameraHeightM) ||
        !_isPositive(angleSpanRadians)) {
      return double.nan;
    }

    final baseAngleRadians = -math.atan(cameraHeightM / distanceM);
    final topAngleRadians = baseAngleRadians + angleSpanRadians;
    if (topAngleRadians >= math.pi / 2 || topAngleRadians <= -math.pi / 2) {
      return double.nan;
    }

    return cameraHeightM + distanceM * math.tan(topAngleRadians);
  }

  static double widthFromAngularSpan({
    required double distanceM,
    required double angleSpanRadians,
  }) {
    if (!_isPositive(distanceM) ||
        !_isPositive(angleSpanRadians) ||
        angleSpanRadians >= math.pi) {
      return double.nan;
    }

    return 2 * distanceM * math.tan(angleSpanRadians / 2);
  }

  static MeasurementPositionGuidance heightGuidance({
    required double distanceM,
    required double cameraHeightM,
    required double angleSpanRadians,
    required double estimatedHeightM,
    double maximumSpanDegrees = maximumHeightSpanDegrees,
  }) {
    final baseAngleRadians = -math.atan(cameraHeightM / distanceM);
    final topAngleRadians = baseAngleRadians + angleSpanRadians;
    final spanDegrees = radiansToDegrees(angleSpanRadians.abs());
    final topAngleDegrees = radiansToDegrees(topAngleRadians);
    final isTooClose =
        topAngleDegrees > maximumHeightViewingAngleDegrees ||
        spanDegrees > maximumSpanDegrees;

    return MeasurementPositionGuidance(
      isTooClose: isTooClose,
      angleSpanDegrees: spanDegrees,
      viewingAngleDegrees: topAngleDegrees,
      recommendedDistanceM: isTooClose
          ? recommendedHeightDistanceM(
              estimatedHeightM: estimatedHeightM,
              cameraHeightM: cameraHeightM,
            )
          : null,
    );
  }

  static MeasurementPositionGuidance canopyGuidance({
    required double distanceM,
    required double angleSpanRadians,
    required double estimatedWidthM,
  }) {
    final spanDegrees = radiansToDegrees(angleSpanRadians.abs());
    final isTooClose = spanDegrees > maximumCanopySpanDegrees;

    return MeasurementPositionGuidance(
      isTooClose: isTooClose,
      angleSpanDegrees: spanDegrees,
      recommendedDistanceM: isTooClose
          ? estimatedWidthM /
                (2 * math.tan(degreesToRadians(targetCanopySpanDegrees / 2)))
          : null,
    );
  }

  static double recommendedHeightDistanceM({
    required double estimatedHeightM,
    required double cameraHeightM,
  }) {
    if (!_isPositive(estimatedHeightM) || !_isPositive(cameraHeightM)) {
      return double.nan;
    }

    final verticalDistanceToTop = math.max(
      0.0,
      estimatedHeightM - cameraHeightM,
    );
    final distanceForTopAngle =
        verticalDistanceToTop /
        math.tan(degreesToRadians(targetHeightViewingAngleDegrees));
    final distanceForSpan = _distanceForHeightSpan(
      estimatedHeightM: estimatedHeightM,
      cameraHeightM: cameraHeightM,
      targetSpanRadians: degreesToRadians(targetHeightSpanDegrees),
    );

    return math.max(distanceForTopAngle, distanceForSpan);
  }

  static double? cameraElevationRadians({
    required double x,
    required double y,
    required double z,
  }) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (!magnitude.isFinite || magnitude < 0.001) {
      return null;
    }

    final normalizedZ = (z / magnitude).clamp(-1.0, 1.0).toDouble();
    return -math.asin(normalizedZ);
  }

  static double angularDifferenceRadians(double first, double second) {
    var difference = (second - first) % (2 * math.pi);
    if (difference > math.pi) {
      difference -= 2 * math.pi;
    } else if (difference < -math.pi) {
      difference += 2 * math.pi;
    }
    return difference.abs();
  }

  static double degreesToRadians(double degrees) => degrees * math.pi / 180;

  static double radiansToDegrees(double radians) => radians * 180 / math.pi;

  static double _distanceForHeightSpan({
    required double estimatedHeightM,
    required double cameraHeightM,
    required double targetSpanRadians,
  }) {
    var low = 0.01;
    var high = math.max(10.0, estimatedHeightM * 10);

    for (var iteration = 0; iteration < 64; iteration++) {
      final middle = (low + high) / 2;
      final span = _heightSpanAtDistance(
        distanceM: middle,
        heightM: estimatedHeightM,
        cameraHeightM: cameraHeightM,
      );
      if (span > targetSpanRadians) {
        low = middle;
      } else {
        high = middle;
      }
    }

    return high;
  }

  static double _heightSpanAtDistance({
    required double distanceM,
    required double heightM,
    required double cameraHeightM,
  }) {
    final baseAngle = -math.atan(cameraHeightM / distanceM);
    final topAngle = math.atan((heightM - cameraHeightM) / distanceM);
    return (topAngle - baseAngle).abs();
  }

  static bool _isPositive(double value) => value.isFinite && value > 0;
}
