import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/transects/data/models/transect_point_model.dart';
import 'package:silvamang_mobile/features/transects/data/services/transect_geometry_service.dart';

void main() {
  const geometry = TransectGeometryService();
  final recordedAt = DateTime.utc(2026, 9, 15, 8);

  TransectPointModel point(
    double latitude,
    double longitude, {
    double? accuracy,
    Duration offset = Duration.zero,
  }) {
    return TransectPointModel(
      latitude: latitude,
      longitude: longitude,
      accuracyM: accuracy,
      recordedAt: recordedAt.add(offset),
    );
  }

  test('calculates Haversine polyline distance and east bearing', () {
    final summary = geometry.summarize([
      point(0, 0, accuracy: 4),
      point(0, 0.0005, accuracy: 6),
      point(0, 0.001, accuracy: 5),
    ]);

    expect(summary.distanceM, closeTo(111.2, 0.5));
    expect(summary.bearingDegrees, closeTo(90, 0.1));
    expect(summary.averageAccuracyM, closeTo(5, 0.01));
  });

  test('rejects inaccurate and stationary GPS samples', () {
    final previous = point(14.5995, 120.9842, accuracy: 4);

    expect(
      geometry.shouldAppendGpsPoint(
        previous: previous,
        candidate: point(
          14.5995,
          120.9847,
          accuracy: 60,
          offset: const Duration(seconds: 4),
        ),
      ),
      isFalse,
    );
    expect(
      geometry.shouldAppendGpsPoint(
        previous: previous,
        candidate: point(
          14.599505,
          120.9842,
          accuracy: 4,
          offset: const Duration(seconds: 4),
        ),
      ),
      isFalse,
    );
  });

  test('keeps meaningful movement after the time fallback', () {
    final previous = point(0, 0, accuracy: 4);
    final candidate = point(
      0.000012,
      0,
      accuracy: 4,
      offset: const Duration(seconds: 9),
    );

    expect(
      geometry.shouldAppendGpsPoint(previous: previous, candidate: candidate),
      isTrue,
    );
  });
}
