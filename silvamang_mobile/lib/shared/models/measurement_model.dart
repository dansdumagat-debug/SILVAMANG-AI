class MeasurementModel {
  const MeasurementModel({
    required this.heightM,
    required this.canopyWidthM,
    this.dbhCm,
    this.gbhCm,
    this.gbhM,
    this.dbhM,
    this.basalAreaM2,
    this.canopy1M,
    this.canopy2M,

    required this.method,
    required this.confidence,
    this.notes = '',
    this.measuredAt,
  });

  final double heightM;
  final double canopyWidthM;
  final double? dbhCm;
  final double? gbhCm;
  final double? gbhM;
  final double? dbhM;
  final double? basalAreaM2;
  final double? canopy1M;
  final double? canopy2M;

  final String method;
  final double confidence;
  final String notes;
  final DateTime? measuredAt;

  factory MeasurementModel.fromJson(Map<String, dynamic> json) {
    return MeasurementModel(
      heightM: _asDouble(json['height_m'] ?? json['heightM']),
      canopyWidthM: _asDouble(json['canopy_width_m'] ?? json['canopyWidthM']),
      dbhCm: _asNullableDouble(json['dbh_cm'] ?? json['dbhCm']),
      gbhCm: _asNullableDouble(json['gbh_cm'] ?? json['gbhCm']),
      gbhM: _asNullableDouble(json['gbh_m'] ?? json['gbhM']),
      dbhM: _asNullableDouble(json['dbh_m'] ?? json['dbhM']),
      basalAreaM2: _asNullableDouble(
        json['basal_area_m2'] ?? json['basalAreaM2'],
      ),
      canopy1M: _asNullableDouble(json['canopy_1_m'] ?? json['canopy1M']),
      canopy2M: _asNullableDouble(json['canopy_2_m'] ?? json['canopy2M']),
      method: _asString(json['measurement_method'] ?? json['method']),
      confidence: _asDouble(json['confidence']),
      notes: _asString(json['notes']),
      measuredAt: _asDate(json['measured_at'] ?? json['measuredAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'height_m': heightM.isFinite && heightM > 0 ? heightM : null,
      'canopy_width_m': canopyWidthM.isFinite && canopyWidthM > 0
          ? canopyWidthM
          : null,
      'dbh_cm': dbhCm,
      'gbh_cm': gbhCm,
      'gbh_m': gbhM,
      'dbh_m': dbhM,
      'basal_area_m2': basalAreaM2,
      'canopy_1_m': canopy1M,
      'canopy_2_m': canopy2M,
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
