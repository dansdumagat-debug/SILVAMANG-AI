import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/field_distance_measurement.dart';
import '../../data/services/field_distance_service.dart';

final fieldDistanceControllerProvider =
    StateNotifierProvider<FieldDistanceController, FieldDistanceState>((ref) {
      return FieldDistanceController(service: const FieldDistanceService());
    });

class FieldDistanceState {
  const FieldDistanceState({
    this.measurement = FieldDistanceMeasurement.empty,
    this.currentPoint,
    this.liveDistanceMeters,
    this.isLoading = false,
    this.isWatching = false,
    this.errorMessage,
    this.successMessage,
  });

  final FieldDistanceMeasurement measurement;
  final FieldDistancePoint? currentPoint;
  final double? liveDistanceMeters;
  final bool isLoading;
  final bool isWatching;
  final String? errorMessage;
  final String? successMessage;

  bool get hasDistance => measurement.hasDistance;

  FieldDistanceState copyWith({
    FieldDistanceMeasurement? measurement,
    FieldDistancePoint? currentPoint,
    double? liveDistanceMeters,
    bool? isLoading,
    bool? isWatching,
    String? errorMessage,
    String? successMessage,
    bool clearCurrent = false,
    bool clearLiveDistance = false,
    bool clearMessages = false,
  }) {
    return FieldDistanceState(
      measurement: measurement ?? this.measurement,
      currentPoint: clearCurrent ? null : currentPoint ?? this.currentPoint,
      liveDistanceMeters: clearLiveDistance
          ? null
          : liveDistanceMeters ?? this.liveDistanceMeters,
      isLoading: isLoading ?? this.isLoading,
      isWatching: isWatching ?? this.isWatching,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      successMessage: clearMessages
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}

class FieldDistanceController extends StateNotifier<FieldDistanceState> {
  FieldDistanceController({required this.service})
    : super(const FieldDistanceState());

  final FieldDistanceService service;
  StreamSubscription<FieldDistancePoint>? _positionSubscription;

  Future<void> setStandingPoint() async {
    state = state.copyWith(
      isLoading: true,
      clearMessages: true,
      clearCurrent: true,
      clearLiveDistance: true,
    );

    try {
      final point = await service.getCurrentPoint();
      final warning = _accuracyWarning(point.accuracyM);
      final measurement = FieldDistanceMeasurement(
        startPoint: point,
        distanceReliability: _accuracyStatus(point.accuracyM),
        status: 'Standing point set. Walk toward the mangrove/front point.',
        warningMessage: warning,
      );

      state = state.copyWith(
        measurement: measurement,
        currentPoint: point,
        liveDistanceMeters: 0,
        isLoading: false,
        successMessage: 'Standing point set.',
      );

      if (kDebugMode) {
        debugPrint(
          'SILVAMANG AI field distance start: '
          '${point.latitude}, ${point.longitude}, accuracy ${point.accuracyM}',
        );
      }

      _startLiveDistance();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  Future<void> setTargetPoint() async {
    final startPoint = state.measurement.startPoint;
    if (startPoint == null) {
      state = state.copyWith(
        errorMessage: 'Set Standing Point before setting a target point.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      final targetPoint = await service.getCurrentPoint();
      final distanceMeters = service.distanceBetweenPoints(
        startPoint,
        targetPoint,
      );
      final warning = _distanceWarning(
        distanceMeters: distanceMeters,
        startAccuracyM: startPoint.accuracyM,
        targetAccuracyM: targetPoint.accuracyM,
      );
      final reliability = _combinedReliability(
        startPoint.accuracyM,
        targetPoint.accuracyM,
      );

      await _stopLiveDistance();

      state = state.copyWith(
        measurement: state.measurement.copyWith(
          targetPoint: targetPoint,
          distanceMeters: distanceMeters,
          distanceSource: 'gps_walk_measurement',
          distanceReliability: reliability,
          status: 'Estimated distance ready for scan.',
          warningMessage: warning,
          clearWarning: warning == null,
        ),
        currentPoint: targetPoint,
        liveDistanceMeters: distanceMeters,
        isLoading: false,
        successMessage: 'Target point set. Estimated distance is ready.',
      );

      if (kDebugMode) {
        debugPrint(
          'SILVAMANG AI field distance target: '
          '${targetPoint.latitude}, ${targetPoint.longitude}, '
          'accuracy ${targetPoint.accuracyM}',
        );
        debugPrint(
          'SILVAMANG AI field distance meters: '
          '${distanceMeters.toStringAsFixed(2)}',
        );
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(error),
      );
    }
  }

  void useDistanceForScan() {
    if (!state.measurement.hasDistance) {
      state = state.copyWith(
        errorMessage: 'Set Target Point before using distance for scan.',
      );
      return;
    }

    state = state.copyWith(
      measurement: state.measurement.copyWith(
        status: 'Distance attached to scan session.',
      ),
      successMessage: 'Estimated distance attached to scan session.',
    );
  }

  void reset() {
    _stopLiveDistance();
    state = const FieldDistanceState();
  }

  void _startLiveDistance() {
    _stopLiveDistance();
    final startPoint = state.measurement.startPoint;
    if (startPoint == null) {
      return;
    }

    state = state.copyWith(isWatching: true);
    _positionSubscription = service.watchCurrentPoint().listen(
      (point) {
        final distanceMeters = service.distanceBetweenPoints(startPoint, point);
        final warning = _distanceWarning(
          distanceMeters: distanceMeters,
          startAccuracyM: startPoint.accuracyM,
          targetAccuracyM: point.accuracyM,
        );
        state = state.copyWith(
          currentPoint: point,
          liveDistanceMeters: distanceMeters,
          measurement: state.measurement.copyWith(
            distanceReliability: _combinedReliability(
              startPoint.accuracyM,
              point.accuracyM,
            ),
            status: 'Walking to target point.',
            warningMessage: warning,
            clearWarning: warning == null,
          ),
        );
      },
      onError: (Object error) {
        state = state.copyWith(
          isWatching: false,
          errorMessage: _friendlyError(error),
        );
      },
    );
  }

  Future<void> _stopLiveDistance() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    if (subscription != null) {
      await subscription.cancel();
    }
    if (mounted) {
      state = state.copyWith(isWatching: false);
    }
  }

  String? _distanceWarning({
    required double distanceMeters,
    required double startAccuracyM,
    required double targetAccuracyM,
  }) {
    final accuracyWarning = _accuracyWarning(
      startAccuracyM > targetAccuracyM ? startAccuracyM : targetAccuracyM,
    );
    if (distanceMeters < 1) {
      return 'Distance too short. Please remeasure.';
    }
    return accuracyWarning;
  }

  String? _accuracyWarning(double accuracyM) {
    if (accuracyM > 30) {
      return 'GPS accuracy is too low for reliable measurement. Move to an open area and try again.';
    }
    if (accuracyM > 10) {
      return 'GPS accuracy is moderate. Distance may be approximate.';
    }
    return null;
  }

  String _combinedReliability(double startAccuracyM, double targetAccuracyM) {
    return _accuracyStatus(
      startAccuracyM > targetAccuracyM ? startAccuracyM : targetAccuracyM,
    );
  }

  String _accuracyStatus(double accuracyM) {
    if (accuracyM > 30) {
      return 'Poor';
    }
    if (accuracyM > 10) {
      return 'Fair';
    }
    return 'Good';
  }

  String _friendlyError(Object error) {
    if (error is FieldDistanceException) {
      return error.message;
    }
    if (error is TimeoutException) {
      return 'GPS did not respond in time. Move to an open area and try again.';
    }
    return 'Unable to capture GPS distance. Please try again.';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
