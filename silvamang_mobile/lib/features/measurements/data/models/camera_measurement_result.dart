class CameraMeasurementPoint {
  const CameraMeasurementPoint({
    required this.label,
    required this.timestamp,
    required this.frameCenterX,
    required this.frameCenterY,
    required this.deviceOrientation,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.locationStatus = 'Location unavailable',
  });

  final String label;
  final DateTime timestamp;
  final double frameCenterX;
  final double frameCenterY;
  final String deviceOrientation;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String locationStatus;

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'timestamp': timestamp.toIso8601String(),
      'frame_center_x': frameCenterX,
      'frame_center_y': frameCenterY,
      'device_orientation': deviceOrientation,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'location_status': locationStatus,
    };
  }
}

class CameraMeasurementResult {
  const CameraMeasurementResult({
    required this.measurementType,
    required this.measurementMode,
    required this.estimatedValueM,
    required this.methodUsed,
    required this.distanceSource,
    required this.distanceM,
    required this.arSupported,
    required this.arUsed,
    required this.reliability,
    required this.warningMessage,
    required this.createdAt,
    this.basePoint,
    this.topPoint,
    this.leftEdgePoint,
    this.rightEdgePoint,
  });

  final String measurementType;
  final String measurementMode;
  final double estimatedValueM;
  final String methodUsed;
  final String distanceSource;
  final double distanceM;
  final CameraMeasurementPoint? basePoint;
  final CameraMeasurementPoint? topPoint;
  final CameraMeasurementPoint? leftEdgePoint;
  final CameraMeasurementPoint? rightEdgePoint;
  final bool arSupported;
  final bool arUsed;
  final String reliability;
  final String warningMessage;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'measurement_type': measurementType,
      'measurement_mode': measurementMode,
      'estimated_value_m': estimatedValueM,
      'method_used': methodUsed,
      'distance_source': distanceSource,
      'distance_m': distanceM,
      'base_point': basePoint?.toJson(),
      'top_point': topPoint?.toJson(),
      'left_edge_point': leftEdgePoint?.toJson(),
      'right_edge_point': rightEdgePoint?.toJson(),
      'ar_supported': arSupported,
      'ar_used': arUsed,
      'reliability': reliability,
      'warning_message': warningMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
