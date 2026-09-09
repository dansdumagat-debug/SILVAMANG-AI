import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../models/mock_ai_prediction_response.dart';
import '../services/offline_prediction_service.dart';

final mockAiPredictionRepositoryProvider = Provider<MockAiPredictionRepository>(
  (ref) {
    return MockAiPredictionRepository(
      apiClient: ApiClient.instance,
      connectivityService: const ConnectivityService(),
      offlinePredictionService: OfflinePredictionService(),
    );
  },
);

class MockAiPredictionRepository {
  const MockAiPredictionRepository({
    required this.apiClient,
    required this.connectivityService,
    required this.offlinePredictionService,
  });

  final ApiClient apiClient;
  final ConnectivityService connectivityService;
  final OfflinePredictionService offlinePredictionService;

  Future<MockAiPredictionResponse> predict({
    required List<CapturedPlantPartImage> capturedImages,
    double? latitude,
    double? longitude,
    double? subjectDistanceM,
    bool forceOffline = false,
  }) async {
    if (capturedImages.isEmpty) {
      throw const ApiException(
        'No image selected. Please capture or select an image first.\nReason: no_selected_image',
      );
    }

    if (kDebugMode) {
      debugPrint('SILVAMANG AI offline mode enabled: $forceOffline');
      debugPrint('SILVAMANG AI selected image count: ${capturedImages.length}');
      debugPrint(
        'SILVAMANG AI selected image path: '
        '${capturedImages.first.imagePath}',
      );
    }

    Object? onlineError;
    final isOnline = forceOffline
        ? false
        : await connectivityService.isOnline();
    if (!forceOffline && isOnline) {
      try {
        if (kDebugMode) {
          debugPrint('SILVAMANG AI online prediction attempted');
        }

        final prediction = await _predictOnline(
          capturedImages: capturedImages,
          latitude: latitude,
          longitude: longitude,
          subjectDistanceM: subjectDistanceM,
        );

        if (prediction.source == 'python_ai_service' &&
            prediction.isValidCnnResult) {
          return prediction;
        }

        onlineError = StateError(
          'Online prediction returned fallback or invalid source: '
          '${prediction.source}/${prediction.mode}',
        );
      } catch (error) {
        onlineError = error;
      }
    } else if (forceOffline) {
      onlineError = StateError('Offline Mode is enabled.');
    } else {
      onlineError = StateError('No internet connection detected.');
    }

    if (kDebugMode) {
      debugPrint('SILVAMANG AI online prediction failed: $onlineError');
    }

    try {
      final offlineImage = capturedImages.first;
      final imagePath = offlineImage.imagePath.trim();
      final imageFileExists =
          !kIsWeb && imagePath.isNotEmpty && File(imagePath).existsSync();

      if (kDebugMode) {
        debugPrint('SILVAMANG AI image file exists: $imageFileExists');
      }

      if (!imageFileExists) {
        throw const ApiException(
          'Offline model failed to load or run.\nReason: selected_image_missing\nSelected image file is unavailable. Please capture or select the image again.',
        );
      }

      if (kDebugMode) {
        debugPrint('SILVAMANG AI offline prediction started');
      }

      final prediction = await offlinePredictionService.predict(
        imagePath: offlineImage.imagePath,
        previewBytes: offlineImage.previewBytes,
        plantParts: capturedImages.map((image) => image.plantPart).toList(),
      );

      if (kDebugMode) {
        debugPrint('SILVAMANG AI offline prediction completed');
      }

      _debugPredictionResponse(prediction);
      return prediction;
    } on ApiException {
      rethrow;
    } catch (offlineError) {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI offline prediction failed: $offlineError');
        try {
          final diagnostic = await offlinePredictionService.checkOfflineModel();
          debugPrint(
            'SILVAMANG AI offline diagnostic reason: '
            '${diagnostic.failureReason ?? 'none'}',
          );
        } catch (diagnosticError) {
          debugPrint(
            'SILVAMANG AI offline diagnostic failed: $diagnosticError',
          );
        }
      }

      throw ApiException(_offlineFailureMessage(offlineError));
    }
  }

  Future<MockAiPredictionResponse> _predictOnline({
    required List<CapturedPlantPartImage> capturedImages,
    double? latitude,
    double? longitude,
    double? subjectDistanceM,
  }) async {
    _debugPredictionRequest(capturedImages);

    final primaryImage = capturedImages.first;
    final classificationResponse = await apiClient.classifyImage(
      imagePath: primaryImage.imagePath,
      imageBytes: primaryImage.previewBytes,
      fileName: primaryImage.fileName,
      latitude: latitude,
      longitude: longitude,
    );
    final classification = _responseData(classificationResponse.data);
    if ((classification['status'] ?? '').toString().toLowerCase() == 'error') {
      throw ApiException(
        classification['message']?.toString() ?? 'CNN classification failed.',
      );
    }

    final storage = _responseStorage(classificationResponse.data);
    final scanRecordId = _asNullableString(
      storage['scan_record_id'] ?? storage['scanRecordId'],
    );
    final detection = await _optionalAiCall(
      () => apiClient.detectPlantParts(
        imagePath: primaryImage.imagePath,
        imageBytes: primaryImage.previewBytes,
        fileName: primaryImage.fileName,
        latitude: latitude,
        longitude: longitude,
        scanRecordId: scanRecordId,
      ),
    );
    final segmentation = await _optionalAiCall(
      () => apiClient.segmentPlant(
        imagePath: primaryImage.imagePath,
        imageBytes: primaryImage.previewBytes,
        fileName: primaryImage.fileName,
        latitude: latitude,
        longitude: longitude,
        scanRecordId: scanRecordId,
      ),
    );
    final measurement = await _optionalAiCall(
      () => apiClient.measurePlant(
        imagePath: primaryImage.imagePath,
        imageBytes: primaryImage.previewBytes,
        fileName: primaryImage.fileName,
        latitude: latitude,
        longitude: longitude,
        scanRecordId: scanRecordId,
        subjectDistanceM: subjectDistanceM,
      ),
    );

    final prediction = _predictionFromPipeline(
      classification: classification,
      storage: storage,
      detection: detection,
      segmentation: segmentation,
      measurement: measurement,
      capturedImages: capturedImages,
      latitude: latitude,
      longitude: longitude,
    );

    _debugPredictionResponse(prediction);

    return prediction;
  }

  Future<Map<String, dynamic>?> _optionalAiCall(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      return _responseData(response.data);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI optional pipeline step skipped: $error');
      }
      return null;
    }
  }

  MockAiPredictionResponse _predictionFromPipeline({
    required Map<String, dynamic> classification,
    required Map<String, dynamic> storage,
    required Map<String, dynamic>? detection,
    required Map<String, dynamic>? segmentation,
    required Map<String, dynamic>? measurement,
    required List<CapturedPlantPartImage> capturedImages,
    double? latitude,
    double? longitude,
  }) {
    final speciesName = _displaySpeciesName(classification['species_name']);
    final confidence = _asNullableDouble(classification['confidence']);
    final predictions = _classificationPredictions(
      classification,
      speciesName,
      confidence,
    );
    final measurementData = _measurementData(measurement);

    return MockAiPredictionResponse.fromJson({
      'mode': 'cnn_efficientnet_b0',
      'source': 'python_ai_service',
      'warning': null,
      'model': {
        'name': classification['model_name'] ?? 'SILVAMANG CNN Classifier',
        'version': classification['version'] ?? '',
        'type': 'classification',
      },
      'top_prediction': {
        'species_id': null,
        'scientific_name': speciesName,
        'common_name': null,
        'confidence': confidence,
      },
      'predictions': predictions,
      'detections': _asMapList(detection?['detections']),
      'segmentation': segmentation ?? const <String, dynamic>{},
      'pipeline': {
        'classification': classification,
        'detection': detection,
        'segmentation': segmentation,
        'measurement': measurement,
      },
      'storage': storage,
      'explanation':
          'Prediction generated through Laravel API and Python AI service.',
      'measurement': measurementData,
      'location_hint': {
        'latitude': latitude,
        'longitude': longitude,
        'message': latitude != null && longitude != null
            ? 'GPS location was sent with the AI request.'
            : 'GPS location was not available for this AI request.',
      },
      'received': {
        'image_count': capturedImages.length,
        'plant_parts': capturedImages.map((image) => image.plantPart).toList(),
      },
    });
  }

  List<Map<String, dynamic>> _classificationPredictions(
    Map<String, dynamic> classification,
    String speciesName,
    double? confidence,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final row in _asMapList(classification['predictions'])) {
      final predictionSpecies = _displaySpeciesName(row['scientific_name']);
      final predictionConfidence = _asNullableDouble(row['confidence']);
      if (predictionSpecies.isEmpty || predictionConfidence == null) {
        continue;
      }

      rows.add({
        'rank': _asInt(row['rank'], fallback: rows.length + 1),
        'species_id': row['species_id'],
        'scientific_name': predictionSpecies,
        'common_name': row['common_name'],
        'confidence': predictionConfidence,
        'model_name': row['model_name'] ?? classification['model_name'],
        'model_version': row['model_version'] ?? classification['version'],
      });
    }

    if (rows.isEmpty && speciesName.isNotEmpty && confidence != null) {
      rows.add({
        'rank': 1,
        'species_id': null,
        'scientific_name': speciesName,
        'common_name': null,
        'confidence': confidence,
        'model_name': classification['model_name'],
        'model_version': classification['version'],
      });
    }

    return rows;
  }

  Map<String, dynamic> _measurementData(Map<String, dynamic>? measurement) {
    if ((measurement?['status'] ?? '').toString().toLowerCase() != 'success') {
      return const {
        'height_m': null,
        'canopy_width_m': null,
        'dbh_cm': null,
        'measurement_method': 'not_estimated',
        'confidence': null,
      };
    }

    return {
      'height_m': _asNullableDouble(measurement?['height_m']),
      'canopy_width_m': _asNullableDouble(measurement?['canopy_width_m']),
      'dbh_cm': _asNullableDouble(measurement?['dbh_cm']),
      'measurement_method':
          measurement?['measurement_method'] ?? 'midas_depth_estimation',
      'confidence': _asNullableDouble(measurement?['confidence']),
    };
  }

  void _debugPredictionRequest(List<CapturedPlantPartImage> capturedImages) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      'SILVAMANG AI predict API_BASE_URL: '
      '${dotenv.env['API_BASE_URL'] ?? 'https://silvamang-api-service.onrender.com/api'}',
    );
    debugPrint('SILVAMANG AI selected image count: ${capturedImages.length}');
    debugPrint(
      'SILVAMANG AI selected image path: '
      '${capturedImages.first.imagePath}',
    );
    debugPrint(
      'SILVAMANG AI selected plant part: '
      '${capturedImages.first.plantPart}',
    );
    debugPrint(
      'SILVAMANG AI multipart field names used: '
      'image',
    );
  }

  void _debugPredictionResponse(MockAiPredictionResponse response) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('SILVAMANG AI response mode: ${response.mode}');
    debugPrint('SILVAMANG AI response source: ${response.source}');
    debugPrint(
      'SILVAMANG AI response received.image_count: '
      '${response.received.imageCount}',
    );
    debugPrint(
      'SILVAMANG AI response top_prediction.scientific_name: '
      '${response.topPrediction.scientificName}',
    );
  }

  Map<String, dynamic> _responseData(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    return response ?? const <String, dynamic>{};
  }

  Map<String, dynamic> _responseStorage(Map<String, dynamic>? response) {
    return _asMap(response?['storage']);
  }

  List<Map<String, dynamic>> _asMapList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value.map(_asMap).where((item) => item.isNotEmpty).toList();
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }

    return const <String, dynamic>{};
  }

  int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String? _asNullableString(Object? value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
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

  String _displaySpeciesName(Object? value) {
    return value?.toString().replaceAll('_', ' ').trim() ?? '';
  }

  String _offlineFailureMessage(Object error) {
    final text = error.toString().toLowerCase();
    final technicalDetail = _offlineTechnicalDetail(text);
    final reason = switch (text) {
      final value
          when value.contains('web_not_supported') ||
              value.contains('not supported on web') =>
        'Offline prediction is supported on Android only.',
      final value when value.contains('android-only') =>
        'Offline prediction is only available on Android/native mobile.',
      final value
          when value.contains('model_data_asset_missing') ||
              value.contains('onnx_data_asset_missing') =>
        'Reason: ONNX data file missing',
      final value
          when value.contains('model_asset_missing') ||
              value.contains('onnx_asset_missing') =>
        'Reason: ONNX model asset missing',
      final value when value.contains('model_copy_failed') =>
        'Reason: Offline model files could not be copied',
      final value when value.contains('unsupported_model_format') =>
        'Reason: Unsupported model format',
      final value when value.contains('invalid_model_path') =>
        'Reason: Invalid model path',
      final value
          when value.contains('session_creation_failed') ||
              value.contains('onnx_session_creation_failed') =>
        'Reason: Session creation failed$technicalDetail',
      final value
          when value.contains('input_tensor_failed') ||
              value.contains('tensor_creation_failed') ||
              value.contains('input_tensor_creation_failed') =>
        'Reason: Input tensor creation failed',
      final value when value.contains('inference_failed') =>
        'Reason: Inference failed',
      final value when value.contains('output_parse_failed') =>
        'Reason: Output parsing failed',
      final value when value.contains('selected_image_missing') =>
        'Reason: Selected image missing',
      final value when value.contains('no_selected_image') =>
        'Reason: No selected image',
      final value when value.contains('class_order') =>
        'Reason: Class order missing or invalid',
      _ => '',
    };

    if (reason.startsWith('Offline prediction')) {
      return reason;
    }

    return reason.isEmpty
        ? 'Offline model failed to load or run.'
        : 'Offline model failed to load or run.\n$reason';
  }

  String _offlineTechnicalDetail(String text) {
    final asset = RegExp(
      r'selected_model_asset=([^\s\)]+)',
    ).firstMatch(text)?.group(1);
    final size = RegExp(
      r'selected_model_file_size=([0-9]+)',
    ).firstMatch(text)?.group(1);

    if (asset == null && size == null) {
      return '';
    }

    final lines = <String>[];
    if (asset != null) {
      lines.add('Model asset: $asset');
    }
    if (size != null) {
      lines.add('File size: $size bytes');
    }

    return '\n${lines.join('\n')}';
  }
}
