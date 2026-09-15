import 'dart:math' as math;

import '../models/transect_point_model.dart';

class TransectGeometrySummary {
  const TransectGeometrySummary({
    required this.distanceM,
    required this.bearingDegrees,
    required this.averageAccuracyM,
  });

  final double distanceM;
  final double? bearingDegrees;
  final double? averageAccuracyM;
}

class TransectGeometryService {
  const TransectGeometryService();

  static const double earthRadiusM = 6371000;

  TransectGeometrySummary summarize(List<TransectPointModel> points) {
    var distanceM = 0.0;
    for (var index = 1; index < points.length; index++) {
      distanceM += distanceBetween(points[index - 1], points[index]);
    }

    final accuracies = points
        .map((point) => point.accuracyM)
        .whereType<double>()
        .where((accuracy) => accuracy.isFinite && accuracy >= 0)
        .toList();

    return TransectGeometrySummary(
      distanceM: distanceM,
      bearingDegrees: points.length >= 2
          ? initialBearing(points.first, points.last)
          : null,
      averageAccuracyM: accuracies.isEmpty
          ? null
          : accuracies.reduce((sum, accuracy) => sum + accuracy) /
                accuracies.length,
    );
  }

  double distanceBetween(TransectPointModel from, TransectPointModel to) {
    final latitude1 = _toRadians(from.latitude);
    final latitude2 = _toRadians(to.latitude);
    final latitudeDelta = latitude2 - latitude1;
    final longitudeDelta = _toRadians(to.longitude - from.longitude);
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(latitude1) *
            math.cos(latitude2) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    final angularDistance =
        2 * math.atan2(math.sqrt(a), math.sqrt(math.max(0, 1 - a)));
    return earthRadiusM * angularDistance;
  }

  double initialBearing(TransectPointModel from, TransectPointModel to) {
    final latitude1 = _toRadians(from.latitude);
    final latitude2 = _toRadians(to.latitude);
    final longitudeDelta = _toRadians(to.longitude - from.longitude);
    final y = math.sin(longitudeDelta) * math.cos(latitude2);
    final x =
        math.cos(latitude1) * math.sin(latitude2) -
        math.sin(latitude1) * math.cos(latitude2) * math.cos(longitudeDelta);
    return (_toDegrees(math.atan2(y, x)) + 360) % 360;
  }

  bool shouldAppendGpsPoint({
    required TransectPointModel previous,
    required TransectPointModel candidate,
    double maximumAccuracyM = 35,
  }) {
    final accuracy = candidate.accuracyM;
    if (accuracy != null && accuracy > maximumAccuracyM) {
      return false;
    }

    final movementM = distanceBetween(previous, candidate);
    final adaptiveThresholdM = math.max(
      1.5,
      math.min(5.0, (accuracy ?? 6) * 0.25),
    );
    final elapsed = candidate.recordedAt.difference(previous.recordedAt);
    return movementM >= adaptiveThresholdM ||
        (elapsed >= const Duration(seconds: 8) && movementM >= 1);
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
  double _toDegrees(double radians) => radians * 180 / math.pi;
}
