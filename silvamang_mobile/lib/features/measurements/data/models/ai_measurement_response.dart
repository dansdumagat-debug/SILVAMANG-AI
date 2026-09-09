class AiMeasurementResponse {
  const AiMeasurementResponse({required this.message, required this.data});

  final String message;
  final AiMeasurementData data;

  factory AiMeasurementResponse.fromJson(Map<String, dynamic> json) {
    return AiMeasurementResponse(
      message: _asString(json['message'], 'Measurement result ready.'),
      data: AiMeasurementData.fromJson(_asMap(json['data'])),
    );
  }
}

class AiMeasurementData {
  const AiMeasurementData({
    required this.mode,
    required this.source,
    this.heightM,
    this.canopyWidthM,
    required this.measurementMethod,
    required this.confidence,
    required this.referenceObject,
    required this.imageCount,
    this.dbhCm,
    this.warning,
    this.message,
  });

  final String mode;
  final String source;
  final double? heightM;
  final double? canopyWidthM;
  final double? dbhCm;
  final String measurementMethod;
  final double confidence;
  final Map<String, dynamic> referenceObject;
  final int imageCount;
  final String? warning;
  final String? message;

  factory AiMeasurementData.fromJson(Map<String, dynamic> json) {
    return AiMeasurementData(
      mode: _asString(json['mode'], 'measurement'),
      source: _asString(json['source'], 'laravel'),
      heightM: _asNullableDouble(json['height_m']),
      canopyWidthM: _asNullableDouble(json['canopy_width_m']),
      dbhCm: _asNullableDouble(json['dbh_cm']),
      measurementMethod: _asString(
        json['measurement_method'],
        'depth_estimation_mock',
      ),
      confidence: _asDouble(json['confidence']),
      referenceObject: _asMap(json['reference_object']),
      imageCount: _asInt(json['image_count']),
      warning: _asNullableString(json['warning']),
      message: _asNullableString(json['message']),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }

  return <String, dynamic>{};
}

String _asString(Object? value, String fallback) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String? _asNullableString(Object? value) {
  if (value == null) {
    return null;
  }

  final text = value.toString();
  return text.isEmpty ? null : text;
}

double _asDouble(Object? value) {
  return _asNullableDouble(value) ?? 0;
}

double? _asNullableDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}
