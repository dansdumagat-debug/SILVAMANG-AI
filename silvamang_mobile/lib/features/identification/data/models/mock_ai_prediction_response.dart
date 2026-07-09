import '../../../../shared/models/prediction_model.dart';

class MockAiPredictionResponse {
  const MockAiPredictionResponse({
    required this.mode,
    required this.model,
    required this.topPrediction,
    required this.predictions,
    required this.explanation,
    required this.measurement,
    required this.locationHint,
    required this.received,
  });

  final String mode;
  final MockAiModelInfo model;
  final MockTopPrediction topPrediction;
  final List<PredictionModel> predictions;
  final String explanation;
  final MockAiMeasurement measurement;
  final MockAiLocationHint locationHint;
  final MockAiReceivedInput received;

  factory MockAiPredictionResponse.fromJson(Map<String, dynamic> json) {
    return MockAiPredictionResponse(
      mode: _asString(json['mode'], fallback: 'mock'),
      model: MockAiModelInfo.fromJson(_asMap(json['model'])),
      topPrediction: MockTopPrediction.fromJson(
        _asMap(json['top_prediction'] ?? json['topPrediction']),
      ),
      predictions: _asPredictions(json['predictions']),
      explanation: _asString(json['explanation']),
      measurement: MockAiMeasurement.fromJson(_asMap(json['measurement'])),
      locationHint: MockAiLocationHint.fromJson(
        _asMap(json['location_hint'] ?? json['locationHint']),
      ),
      received: MockAiReceivedInput.fromJson(_asMap(json['received'])),
    );
  }

  static List<PredictionModel> _asPredictions(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(PredictionModel.fromJson)
        .toList();
  }
}

class MockAiModelInfo {
  const MockAiModelInfo({
    required this.name,
    required this.version,
    required this.type,
  });

  final String name;
  final String version;
  final String type;

  factory MockAiModelInfo.fromJson(Map<String, dynamic> json) {
    return MockAiModelInfo(
      name: _asString(json['name'], fallback: 'SILVAMANG Mock Classifier'),
      version: _asString(json['version'], fallback: '0.1.0'),
      type: _asString(json['type'], fallback: 'classification'),
    );
  }
}

class MockTopPrediction {
  const MockTopPrediction({
    this.speciesId,
    required this.scientificName,
    required this.commonName,
    required this.confidence,
  });

  final int? speciesId;
  final String scientificName;
  final String commonName;
  final double confidence;

  factory MockTopPrediction.fromJson(Map<String, dynamic> json) {
    return MockTopPrediction(
      speciesId: _asNullableInt(json['species_id'] ?? json['speciesId']),
      scientificName: _asString(
        json['scientific_name'] ?? json['scientificName'],
        fallback: 'Rhizophora apiculata',
      ),
      commonName: _asString(
        json['common_name'] ?? json['commonName'],
        fallback: 'Red Mangrove',
      ),
      confidence: _asDouble(json['confidence'], fallback: 92.4),
    );
  }
}

class MockAiMeasurement {
  const MockAiMeasurement({
    required this.heightM,
    required this.canopyWidthM,
    this.dbhCm,
    required this.measurementMethod,
    required this.confidence,
  });

  final double heightM;
  final double canopyWidthM;
  final double? dbhCm;
  final String measurementMethod;
  final double confidence;

  factory MockAiMeasurement.fromJson(Map<String, dynamic> json) {
    return MockAiMeasurement(
      heightM: _asDouble(json['height_m'] ?? json['heightM'], fallback: 6.8),
      canopyWidthM: _asDouble(
        json['canopy_width_m'] ?? json['canopyWidthM'],
        fallback: 4.2,
      ),
      dbhCm: _asNullableDouble(json['dbh_cm'] ?? json['dbhCm']),
      measurementMethod: _asString(
        json['measurement_method'] ?? json['measurementMethod'],
        fallback: 'depth_estimation',
      ),
      confidence: _asDouble(json['confidence'], fallback: 88.0),
    );
  }
}

class MockAiLocationHint {
  const MockAiLocationHint({
    this.latitude,
    this.longitude,
    required this.message,
  });

  final double? latitude;
  final double? longitude;
  final String message;

  factory MockAiLocationHint.fromJson(Map<String, dynamic> json) {
    return MockAiLocationHint(
      latitude: _asNullableDouble(json['latitude']),
      longitude: _asNullableDouble(json['longitude']),
      message: _asString(
        json['message'],
        fallback:
            'Location validation will be performed after saving the scan record.',
      ),
    );
  }
}

class MockAiReceivedInput {
  const MockAiReceivedInput({
    required this.plantParts,
    required this.imageCount,
  });

  final List<String> plantParts;
  final int imageCount;

  factory MockAiReceivedInput.fromJson(Map<String, dynamic> json) {
    return MockAiReceivedInput(
      plantParts: _asStringList(json['plant_parts'] ?? json['plantParts']),
      imageCount: _asInt(json['image_count'] ?? json['imageCount']),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const {};
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text;
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _asNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map((item) => item.toString()).toList();
}
