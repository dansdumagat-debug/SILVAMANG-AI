class LocationValidationModel {
  const LocationValidationModel({
    required this.result,
    this.latitude,
    this.longitude,
    this.distanceToKnownDistributionKm,
    required this.message,
    this.validatedAt,
  });

  final String result;
  final double? latitude;
  final double? longitude;
  final double? distanceToKnownDistributionKm;
  final String message;
  final DateTime? validatedAt;

  factory LocationValidationModel.fromJson(Map<String, dynamic> json) {
    return LocationValidationModel(
      result: _asString(json['result']),
      latitude: _asNullableDouble(json['latitude']),
      longitude: _asNullableDouble(json['longitude']),
      distanceToKnownDistributionKm: _asNullableDouble(
        json['distance_to_known_distribution_km'] ??
            json['distanceToKnownDistributionKm'],
      ),
      message: _asString(json['message']),
      validatedAt: _asDate(json['validated_at'] ?? json['validatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'result': result,
      'latitude': latitude,
      'longitude': longitude,
      'distance_to_known_distribution_km': distanceToKnownDistributionKm,
      'message': message,
      'validated_at': validatedAt?.toIso8601String(),
    };
  }

  static String _asString(Object? value) {
    return value?.toString() ?? '';
  }

  static double? _asNullableDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static DateTime? _asDate(Object? value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
