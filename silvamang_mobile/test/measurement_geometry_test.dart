import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/measurements/data/services/measurement_geometry.dart';

void main() {
  group('MeasurementGeometry', () {
    test('reconstructs height from a base-to-top angular span', () {
      const heightM = 10.0;
      const distanceM = 10.0;
      const cameraHeightM = 1.5;
      final baseAngle = -math.atan(cameraHeightM / distanceM);
      final topAngle = math.atan((heightM - cameraHeightM) / distanceM);

      final estimate = MeasurementGeometry.heightFromAngularSpan(
        distanceM: distanceM,
        cameraHeightM: cameraHeightM,
        angleSpanRadians: topAngle - baseAngle,
      );

      expect(estimate, closeTo(heightM, 0.0001));
    });

    test('marks a tall tree measured too closely as unsafe', () {
      const heightM = 10.0;
      const distanceM = 3.0;
      const cameraHeightM = 1.5;
      final baseAngle = -math.atan(cameraHeightM / distanceM);
      final topAngle = math.atan((heightM - cameraHeightM) / distanceM);
      final span = topAngle - baseAngle;

      final guidance = MeasurementGeometry.heightGuidance(
        distanceM: distanceM,
        cameraHeightM: cameraHeightM,
        angleSpanRadians: span,
        estimatedHeightM: heightM,
      );

      expect(guidance.isTooClose, isTrue);
      expect(guidance.recommendedDistanceM, greaterThan(distanceM));
    });

    test('accepts a tall tree from a safer distance', () {
      const heightM = 10.0;
      const distanceM = 10.0;
      const cameraHeightM = 1.5;
      final baseAngle = -math.atan(cameraHeightM / distanceM);
      final topAngle = math.atan((heightM - cameraHeightM) / distanceM);

      final guidance = MeasurementGeometry.heightGuidance(
        distanceM: distanceM,
        cameraHeightM: cameraHeightM,
        angleSpanRadians: topAngle - baseAngle,
        estimatedHeightM: heightM,
      );

      expect(guidance.isTooClose, isFalse);
      expect(guidance.recommendedDistanceM, isNull);
    });

    test('recommended height distance returns to the accepted angle range', () {
      const heightM = 18.0;
      const cameraHeightM = 1.5;
      final recommended = MeasurementGeometry.recommendedHeightDistanceM(
        estimatedHeightM: heightM,
        cameraHeightM: cameraHeightM,
      );
      final baseAngle = -math.atan(cameraHeightM / recommended);
      final topAngle = math.atan((heightM - cameraHeightM) / recommended);

      final guidance = MeasurementGeometry.heightGuidance(
        distanceM: recommended,
        cameraHeightM: cameraHeightM,
        angleSpanRadians: topAngle - baseAngle,
        estimatedHeightM: heightM,
      );

      expect(guidance.isTooClose, isFalse);
    });

    test('extended sweep accepts a long span when the top angle is safe', () {
      const distanceM = 2.0;
      const cameraHeightM = 1.5;
      final baseAngle = -math.atan(cameraHeightM / distanceM);
      final topAngle = MeasurementGeometry.degreesToRadians(55);
      final span = topAngle - baseAngle;
      final height = MeasurementGeometry.heightFromAngularSpan(
        distanceM: distanceM,
        cameraHeightM: cameraHeightM,
        angleSpanRadians: span,
      );

      final normalGuidance = MeasurementGeometry.heightGuidance(
        distanceM: distanceM,
        cameraHeightM: cameraHeightM,
        angleSpanRadians: span,
        estimatedHeightM: height,
      );
      final extendedGuidance = MeasurementGeometry.heightGuidance(
        distanceM: distanceM,
        cameraHeightM: cameraHeightM,
        angleSpanRadians: span,
        estimatedHeightM: height,
        maximumSpanDegrees:
            MeasurementGeometry.maximumExtendedHeightSpanDegrees,
      );

      expect(normalGuidance.isTooClose, isTrue);
      expect(extendedGuidance.isTooClose, isFalse);
    });

    test('converts steady accelerometer gravity into camera elevation', () {
      final level = MeasurementGeometry.cameraElevationRadians(
        x: 0,
        y: 9.81,
        z: 0,
      );
      final thirtyDegreesUp = MeasurementGeometry.cameraElevationRadians(
        x: 0,
        y: 9.81 * math.cos(math.pi / 6),
        z: -9.81 * math.sin(math.pi / 6),
      );

      expect(level, closeTo(0, 0.0001));
      expect(thirtyDegreesUp, closeTo(math.pi / 6, 0.0001));
    });

    test('reconstructs canopy width from horizontal angular span', () {
      final span = 2 * math.atan(5 / 10);

      final estimate = MeasurementGeometry.widthFromAngularSpan(
        distanceM: 10,
        angleSpanRadians: span,
      );

      expect(estimate, closeTo(10, 0.0001));
    });

    test('recommends more distance for an overly wide canopy angle', () {
      final span = MeasurementGeometry.degreesToRadians(80);
      final estimate = MeasurementGeometry.widthFromAngularSpan(
        distanceM: 4,
        angleSpanRadians: span,
      );

      final guidance = MeasurementGeometry.canopyGuidance(
        distanceM: 4,
        angleSpanRadians: span,
        estimatedWidthM: estimate,
      );

      expect(guidance.isTooClose, isTrue);
      expect(guidance.recommendedDistanceM, greaterThan(4));
    });
  });
}
