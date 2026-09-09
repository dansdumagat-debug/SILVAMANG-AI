class CameraPointingPointData {
  const CameraPointingPointData({
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

class CameraPointingMeasurementResult {
  const CameraPointingMeasurementResult({
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
    this.basePointData,
    this.topPointData,
    this.leftEdgePointData,
    this.rightEdgePointData,
  });

  final String measurementType;
  final String measurementMode;
  final double estimatedValueM;
  final String methodUsed;
  final String distanceSource;
  final double distanceM;
  final CameraPointingPointData? basePointData;
  final CameraPointingPointData? topPointData;
  final CameraPointingPointData? leftEdgePointData;
  final CameraPointingPointData? rightEdgePointData;
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
      'base_point_data': basePointData?.toJson(),
      'top_point_data': topPointData?.toJson(),
      'left_edge_point_data': leftEdgePointData?.toJson(),
      'right_edge_point_data': rightEdgePointData?.toJson(),
      'ar_supported': arSupported,
      'ar_used': arUsed,
      'reliability': reliability,
      'warning_message': warningMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
