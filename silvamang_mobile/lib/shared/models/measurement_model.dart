class MeasurementModel {
  const MeasurementModel({
    required this.heightM,
    required this.canopyWidthM,
    this.dbhCm,
    required this.method,
    required this.confidence,
    this.notes = '',
    this.measuredAt,
  });

  final double heightM;
  final double canopyWidthM;
  final double? dbhCm;
  final String method;
  final double confidence;
  final String notes;
  final DateTime? measuredAt;

  factory MeasurementModel.fromJson(Map<String, dynamic> json) {
    return MeasurementModel(
      heightM: _asDouble(json['height_m'] ?? json['heightM']),
      canopyWidthM: _asDouble(json['canopy_width_m'] ?? json['canopyWidthM']),
      dbhCm: _asNullableDouble(json['dbh_cm'] ?? json['dbhCm']),
      method: _asString(json['measurement_method'] ?? json['method']),
      confidence: _asDouble(json['confidence']),
      notes: _asString(json['notes']),
      measuredAt: _asDate(json['measured_at'] ?? json['measuredAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'height_m': heightM,
      'canopy_width_m': canopyWidthM,
      'dbh_cm': dbhCm,
      'measurement_method': method,
      'confidence': confidence,
      'notes': notes,
      'measured_at': measuredAt?.toIso8601String(),
    };
  }

  static String _asString(Object? value) {
    return value?.toString() ?? '';
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
    if (value == null || value.toString().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
