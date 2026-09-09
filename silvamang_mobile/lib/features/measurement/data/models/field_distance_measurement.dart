class FieldDistancePoint {
  const FieldDistancePoint({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.timestamp,
    double? bestAccuracyM,
    double? averageAccuracyM,
  }) : bestAccuracyM = bestAccuracyM ?? accuracyM,
       averageAccuracyM = averageAccuracyM ?? accuracyM;

  final double latitude;
  final double longitude;
  final double accuracyM;
  final double bestAccuracyM;
  final double averageAccuracyM;
  final DateTime timestamp;
}

class FieldDistanceMeasurement {
  const FieldDistanceMeasurement({
    this.startPoint,
    this.targetPoint,
    this.distanceMeters,
    this.distanceSource = 'unavailable',
    this.distanceReliability = 'Unavailable',
    this.status = 'Not measured',
    this.warningMessage,
  });

  static const empty = FieldDistanceMeasurement();

  final FieldDistancePoint? startPoint;
  final FieldDistancePoint? targetPoint;
  final double? distanceMeters;
  final String distanceSource;
  final String distanceReliability;
  final String status;
  final String? warningMessage;

  bool get hasStart => startPoint != null;
  bool get hasTarget => targetPoint != null;
  bool get hasDistance => distanceMeters != null && distanceMeters! > 0;

  FieldDistanceMeasurement copyWith({
    FieldDistancePoint? startPoint,
    FieldDistancePoint? targetPoint,
    double? distanceMeters,
    String? distanceSource,
    String? distanceReliability,
    String? status,
    String? warningMessage,
    bool clearTarget = false,
    bool clearDistance = false,
    bool clearWarning = false,
  }) {
    return FieldDistanceMeasurement(
      startPoint: startPoint ?? this.startPoint,
      targetPoint: clearTarget ? null : targetPoint ?? this.targetPoint,
      distanceMeters: clearDistance
          ? null
          : distanceMeters ?? this.distanceMeters,
      distanceSource: distanceSource ?? this.distanceSource,
      distanceReliability: distanceReliability ?? this.distanceReliability,
      status: status ?? this.status,
      warningMessage: clearWarning
          ? null
          : warningMessage ?? this.warningMessage,
    );
  }
}
