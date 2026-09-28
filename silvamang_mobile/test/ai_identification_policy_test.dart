import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/core/config/ai_identification_config.dart';
import 'package:silvamang_mobile/core/services/api_client.dart';
import 'package:silvamang_mobile/core/services/connectivity_service.dart';
import 'package:silvamang_mobile/features/capture/data/models/captured_plant_part_image.dart';
import 'package:silvamang_mobile/features/identification/data/models/mock_ai_prediction_response.dart';
import 'package:silvamang_mobile/features/identification/data/repositories/mock_ai_prediction_repository.dart';
import 'package:silvamang_mobile/features/identification/data/services/offline_prediction_service.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: 'AI_CONFIDENCE_THRESHOLD=0.70');
  });

  tearDown(dotenv.clean);

  test('accepts a supported mangrove at the configured threshold', () {
    final response = _response(species: 'Rhizophora_apiculata', confidence: 70);

    expect(response.isValidCnnResult, isTrue);
    expect(response.isRejected, isFalse);
  });

  test('rejects a low-confidence coconut false positive', () {
    final response = _response(species: 'Sonneratia_alba', confidence: 42);

    expect(response.isValidCnnResult, isFalse);
    expect(response.isRejected, isTrue);
    expect(response.rejectionMessage, contains('enough confidence'));
  });

  test('asks for a clearer capture when a blurred image is uncertain', () {
    final response = _response(
      species: 'Rhizophora_apiculata',
      confidence: 35,
      status: 'uncertain',
    );

    expect(response.isValidCnnResult, isFalse);
    expect(response.isRejected, isTrue);
    expect(response.rejectionRecommendation, contains('clear photo'));
  });

  test('does not expose unknown as a species result', () {
    final response = _response(species: 'unknown', confidence: 96);

    expect(response.isValidCnnResult, isFalse);
    expect(response.validPredictions, isEmpty);
    expect(
      response.rejectionMessage,
      'The captured image does not appear to be a supported mangrove species.',
    );
    expect(
      response.rejectionRecommendation,
      'Please capture mangrove leaves, roots, bark, flowers, or canopy structures.',
    );
  });

  test('treats a non-mangrove alias as unknown', () {
    final response = _response(species: 'non-mangrove', confidence: 96);

    expect(response.isRejected, isTrue);
    expect(response.validPredictions, isEmpty);
  });

  test('treats a non-mangrove status alias as unknown', () {
    final response = _response(
      species: 'Rhizophora_apiculata',
      confidence: 99,
      status: 'not_mangrove',
    );

    expect(response.isRejected, isTrue);
    expect(response.rejectionMessage, contains('does not appear'));
  });

  test('uses the no-structure response for a random object', () {
    final response = _response(
      species: '',
      confidence: double.nan,
      status: 'no_structure',
      message:
          'No mangrove structure detected. Please capture a valid mangrove image.',
    );

    expect(response.isRejected, isTrue);
    expect(response.rejectionMessage, startsWith('No mangrove structure'));
  });

  test('invalid configuration falls back to the documented threshold', () {
    expect(
      AiIdentificationConfig.parseConfidenceThreshold('1.2'),
      AiIdentificationConfig.defaultConfidenceThreshold,
    );
  });

  test(
    'YOLO no-structure result stops classification and persistence',
    () async {
      final apiClient = _NoStructureAiClient();
      final repository = MockAiPredictionRepository(
        apiClient: apiClient,
        connectivityService: const _AlwaysOnlineConnectivityService(),
        offlinePredictionService: OfflinePredictionService(),
      );

      final response = await repository.predict(
        capturedImages: [
          CapturedPlantPartImage(
            plantPart: 'leaves',
            imagePath: '',
            fileName: 'random-object.jpg',
            previewBytes: Uint8List.fromList([1, 2, 3]),
            capturedAt: DateTime(2026),
            source: 'gallery',
          ),
        ],
      );

      expect(response.normalizedStatus, 'no_structure');
      expect(response.isRejected, isTrue);
      expect(apiClient.detectCalls, 1);
      expect(apiClient.classifyCalls, 0);
      expect(apiClient.segmentCalls, 0);
      expect(apiClient.lastPersistResult, isFalse);
      expect(response.serverScanRecordId, isNull);
    },
  );
}

MockAiPredictionResponse _response({
  required String species,
  required double confidence,
  String status = 'success',
  String? message,
}) {
  return MockAiPredictionResponse.fromJson({
    'status': status,
    'message': message,
    'mode': 'offline_onnx_efficientnet_b0',
    'source': 'flutter_offline_model',
    'model': {'name': 'EfficientNet-B0', 'version': 'test'},
    'top_prediction': {
      'scientific_name': species,
      'common_name': '',
      'confidence': confidence,
    },
    'predictions': [
      {
        'rank': 1,
        'scientific_name': species,
        'common_name': '',
        'confidence': confidence,
      },
    ],
    'received': {
      'image_count': 1,
      'plant_parts': ['leaves'],
    },
  });
}

class _AlwaysOnlineConnectivityService extends ConnectivityService {
  const _AlwaysOnlineConnectivityService();

  @override
  Future<bool> isOnline() async => true;
}

class _NoStructureAiClient implements AiInferenceClient {
  int classifyCalls = 0;
  int detectCalls = 0;
  int segmentCalls = 0;
  bool? lastPersistResult;

  @override
  Future<Response<Map<String, dynamic>>> detectPlantParts({
    String? imagePath,
    List<int>? imageBytes,
    String fileName = 'scan.jpg',
    String? imageBase64,
    double? latitude,
    double? longitude,
    String? scanRecordId,
    bool persistResult = true,
  }) async {
    detectCalls++;
    lastPersistResult = persistResult;

    return Response(
      requestOptions: RequestOptions(path: '/ai/detect'),
      statusCode: 200,
      data: {
        'data': {
          'status': 'no_structure',
          'message':
              'No mangrove structure detected. Please capture a valid mangrove image.',
          'detections': <Map<String, dynamic>>[],
        },
        'storage': {'stored': false},
      },
    );
  }

  @override
  Future<Response<Map<String, dynamic>>> classifyImage({
    String? imagePath,
    List<int>? imageBytes,
    String fileName = 'scan.jpg',
    String? imageBase64,
    double? latitude,
    double? longitude,
    String? scanRecordId,
  }) {
    classifyCalls++;
    throw StateError('Classifier must not run after no_structure.');
  }

  @override
  Future<Response<Map<String, dynamic>>> segmentPlant({
    String? imagePath,
    List<int>? imageBytes,
    String fileName = 'scan.jpg',
    String? imageBase64,
    double? latitude,
    double? longitude,
    String? scanRecordId,
  }) {
    segmentCalls++;
    throw StateError('Segmentation must not run after no_structure.');
  }
}
