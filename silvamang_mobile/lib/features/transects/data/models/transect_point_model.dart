class TransectPointModel {
  const TransectPointModel({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracyM,
    this.altitudeM,
  });

  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double? altitudeM;
  final DateTime recordedAt;

  factory TransectPointModel.fromJson(Map<String, dynamic> json) {
    return TransectPointModel(
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      accuracyM: _asNullableDouble(json['accuracy_m'] ?? json['accuracyM']),
      altitudeM: _asNullableDouble(json['altitude_m'] ?? json['altitudeM']),
      recordedAt:
          _asDate(json['recorded_at'] ?? json['recordedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'altitude_m': altitudeM,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
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
    final text = value?.toString();
    return text == null || text.isEmpty ? null : DateTime.tryParse(text);
  }
}
