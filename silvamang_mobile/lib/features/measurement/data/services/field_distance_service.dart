import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/field_distance_measurement.dart';

class FieldDistanceException implements Exception {
  const FieldDistanceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FieldDistanceService {
  const FieldDistanceService();

  Future<FieldDistancePoint> getCurrentPoint({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return getAveragedPoint(timeout: timeout);
  }

  Future<FieldDistancePoint> getAveragedPoint({
    int sampleCount = 7,
    Duration timeout = const Duration(seconds: 14),
  }) async {
    await _ensurePermission();
    final samples = <Position>[];
    StreamSubscription<Position>? subscription;

    try {
      final completer = Completer<void>();
      subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
            ),
          ).listen((position) {
            samples.add(position);
            if (samples.length >= sampleCount && !completer.isCompleted) {
              completer.complete();
            }
          });

      await completer.future.timeout(
        timeout,
        onTimeout: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );
    } finally {
      await subscription?.cancel();
    }

    if (samples.isEmpty) {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: timeout,
        ),
      );
      samples.add(position);
    }

    return _averageSamples(samples);
  }

  Stream<FieldDistancePoint> watchCurrentPoint() async* {
    await _ensurePermission();
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 2,
      ),
    ).map(_fromPosition);
  }

  double distanceBetweenPoints(
    FieldDistancePoint start,
    FieldDistancePoint target,
  ) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      target.latitude,
      target.longitude,
    );
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const FieldDistanceException(
        'GPS/location service is disabled. Please enable location services.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const FieldDistanceException(
        'Location permission denied. Allow location access to measure distance.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const FieldDistanceException(
        'Location permission denied forever. Enable it in phone settings.',
      );
    }
  }

  FieldDistancePoint _fromPosition(Position position) {
    return FieldDistancePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
      bestAccuracyM: position.accuracy,
      averageAccuracyM: position.accuracy,
      timestamp: position.timestamp,
    );
  }

  FieldDistancePoint _averageSamples(List<Position> samples) {
    final acceptedSamples = _acceptedSamples(samples);
    final latitude =
        acceptedSamples.fold<double>(
          0,
          (sum, sample) => sum + sample.latitude,
        ) /
        acceptedSamples.length;
    final longitude =
        acceptedSamples.fold<double>(
          0,
          (sum, sample) => sum + sample.longitude,
        ) /
        acceptedSamples.length;
    final averageAccuracy =
        acceptedSamples.fold<double>(
          0,
          (sum, sample) => sum + sample.accuracy,
        ) /
        acceptedSamples.length;
    final bestAccuracy = acceptedSamples
        .map((sample) => sample.accuracy)
        .reduce((best, accuracy) => accuracy < best ? accuracy : best);

    return FieldDistancePoint(
      latitude: latitude,
      longitude: longitude,
      accuracyM: averageAccuracy,
      bestAccuracyM: bestAccuracy,
      averageAccuracyM: averageAccuracy,
      timestamp: DateTime.now(),
    );
  }

  List<Position> _acceptedSamples(List<Position> samples) {
    final goodSamples = samples
        .where((sample) => sample.accuracy <= 10)
        .toList();
    if (goodSamples.length >= 3) {
      return goodSamples;
    }

    final fairSamples = samples
        .where((sample) => sample.accuracy <= 30)
        .toList();
    if (fairSamples.length >= 3) {
      return fairSamples;
    }

    final sortedSamples = [...samples]
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final takeCount = sortedSamples.length <= 3
        ? sortedSamples.length
        : (sortedSamples.length / 2).ceil();

    return sortedSamples.take(takeCount).toList();
  }
}
