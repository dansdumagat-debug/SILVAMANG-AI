import '../../../../shared/models/prediction_model.dart';
import 'mock_ai_prediction_response.dart';

class MockIdentificationResult {
  const MockIdentificationResult({
    required this.scientificName,
    required this.commonName,
    this.speciesId,
    required this.confidence,
    required this.captureMode,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.address,
    required this.predictions,
    required this.heightM,
    required this.canopyWidthM,
    this.dbhCm,
    required this.measurementConfidence,
    required this.validationResult,
    required this.validationMessage,
    required this.distanceToKnownDistributionKm,
    this.explanation = '',
  });

  final String scientificName;
  final String commonName;
  final int? speciesId;
  final double confidence;
  final String captureMode;
  final double latitude;
  final double longitude;
  final String locationName;
  final String address;
  final List<PredictionModel> predictions;
  final double heightM;
  final double canopyWidthM;
  final double? dbhCm;
  final double measurementConfidence;
  final String validationResult;
  final String validationMessage;
  final double distanceToKnownDistributionKm;
  final String explanation;

  MockIdentificationResult copyWith({
    String? scientificName,
    String? commonName,
    int? speciesId,
    double? confidence,
    String? captureMode,
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
    List<PredictionModel>? predictions,
    double? heightM,
    double? canopyWidthM,
    double? dbhCm,
    double? measurementConfidence,
    String? validationResult,
    String? validationMessage,
    double? distanceToKnownDistributionKm,
    String? explanation,
  }) {
    return MockIdentificationResult(
      scientificName: scientificName ?? this.scientificName,
      commonName: commonName ?? this.commonName,
      speciesId: speciesId ?? this.speciesId,
      confidence: confidence ?? this.confidence,
      captureMode: captureMode ?? this.captureMode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      predictions: predictions ?? this.predictions,
      heightM: heightM ?? this.heightM,
      canopyWidthM: canopyWidthM ?? this.canopyWidthM,
      dbhCm: dbhCm ?? this.dbhCm,
      measurementConfidence:
          measurementConfidence ?? this.measurementConfidence,
      validationResult: validationResult ?? this.validationResult,
      validationMessage: validationMessage ?? this.validationMessage,
      distanceToKnownDistributionKm:
          distanceToKnownDistributionKm ?? this.distanceToKnownDistributionKm,
      explanation: explanation ?? this.explanation,
    );
  }

  factory MockIdentificationResult.fromMockAiResponse(
    MockAiPredictionResponse response, {
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
  }) {
    final fallback = MockIdentificationResult.sample;
    return MockIdentificationResult(
      scientificName: response.topPrediction.scientificName.isNotEmpty
          ? response.topPrediction.scientificName
          : fallback.scientificName,
      commonName: response.topPrediction.commonName.isNotEmpty
          ? response.topPrediction.commonName
          : fallback.commonName,
      speciesId: response.topPrediction.speciesId,
      confidence: response.topPrediction.confidence,
      captureMode: fallback.captureMode,
      latitude: response.locationHint.latitude ?? latitude ?? fallback.latitude,
      longitude:
          response.locationHint.longitude ?? longitude ?? fallback.longitude,
      locationName: locationName ?? fallback.locationName,
      address: address ?? fallback.address,
      predictions: response.predictions.isEmpty
          ? fallback.predictions
          : response.predictions,
      heightM: response.measurement.heightM,
      canopyWidthM: response.measurement.canopyWidthM,
      dbhCm: response.measurement.dbhCm,
      measurementConfidence: response.measurement.confidence,
      validationResult: fallback.validationResult,
      validationMessage: response.locationHint.message,
      distanceToKnownDistributionKm: fallback.distanceToKnownDistributionKm,
      explanation: response.explanation,
    );
  }

  static const sample = MockIdentificationResult(
    scientificName: 'Rhizophora apiculata',
    commonName: 'Red Mangrove',
    confidence: 92.4,
    captureMode: 'guided',
    latitude: 9.7392,
    longitude: 118.7353,
    locationName: 'Brgy. San Roque, Puerto Princesa, Palawan',
    address: 'Puerto Princesa, Palawan',
    predictions: [
      PredictionModel(
        rank: 1,
        scientificName: 'Rhizophora apiculata',
        commonName: 'Red Mangrove',
        confidence: 92.4,
      ),
      PredictionModel(
        rank: 2,
        scientificName: 'Rhizophora mucronata',
        commonName: 'Loop-root Mangrove',
        confidence: 5.1,
      ),
      PredictionModel(
        rank: 3,
        scientificName: 'Bruguiera gymnorrhiza',
        commonName: 'Large-leafed Orange Mangrove',
        confidence: 2.5,
      ),
    ],
    heightM: 6.8,
    canopyWidthM: 4.2,
    dbhCm: null,
    measurementConfidence: 88.0,
    validationResult: 'match',
    validationMessage: 'Species is commonly found in this area.',
    distanceToKnownDistributionKm: 1.25,
    explanation:
        'This local mock result suggests Rhizophora apiculata for prototype testing.',
  );
}
