class PredictionModel {
  const PredictionModel({
    required this.rank,
    required this.scientificName,
    required this.commonName,
    required this.confidence,
    this.modelName = '',
    this.modelVersion = '',
  });

  final int rank;
  final String scientificName;
  final String commonName;
  final double confidence;
  final String modelName;
  final String modelVersion;

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      rank: _asInt(json['rank']),
      scientificName: _asString(
        json['scientific_name'] ?? json['scientificName'],
      ),
      commonName: _asString(json['common_name'] ?? json['commonName']),
      confidence: _asDouble(json['confidence']),
      modelName: _asString(json['model_name'] ?? json['modelName']),
      modelVersion: _asString(json['model_version'] ?? json['modelVersion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'scientific_name': scientificName,
      'common_name': commonName,
      'confidence': confidence,
      'model_name': modelName,
      'model_version': modelVersion,
    };
  }

  static String _asString(Object? value) {
    return value?.toString() ?? '';
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? double.nan;
  }
}
