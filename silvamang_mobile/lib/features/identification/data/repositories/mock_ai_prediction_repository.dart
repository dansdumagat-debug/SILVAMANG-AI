import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../models/mock_ai_prediction_response.dart';

final mockAiPredictionRepositoryProvider = Provider<MockAiPredictionRepository>(
  (ref) {
    return MockAiPredictionRepository(apiClient: ApiClient.instance);
  },
);

class MockAiPredictionRepository {
  const MockAiPredictionRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<MockAiPredictionResponse> predict({
    required List<CapturedPlantPartImage> capturedImages,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (latitude != null) {
        payload['latitude'] = latitude;
      }
      if (longitude != null) {
        payload['longitude'] = longitude;
      }

      final response = capturedImages.isEmpty
          ? await apiClient.post<Map<String, dynamic>>(
              '/ai/mock-predict',
              data: payload,
            )
          : await apiClient.postForm<Map<String, dynamic>>(
              '/ai/mock-predict',
              data: await _formData(
                capturedImages: capturedImages,
                latitude: latitude,
                longitude: longitude,
              ),
            );

      final data = response.data?['data'];
      if (data is Map<String, dynamic>) {
        return MockAiPredictionResponse.fromJson(data);
      }
      return MockAiPredictionResponse.fromJson(response.data ?? {});
    } catch (_) {
      throw const ApiException(
        'Unable to get mock AI prediction. Please try again.',
      );
    }
  }

  Future<FormData> _formData({
    required List<CapturedPlantPartImage> capturedImages,
    double? latitude,
    double? longitude,
  }) async {
    final formData = FormData();

    if (latitude != null) {
      formData.fields.add(MapEntry('latitude', latitude.toString()));
    }
    if (longitude != null) {
      formData.fields.add(MapEntry('longitude', longitude.toString()));
    }

    for (final image in capturedImages) {
      formData.fields.add(MapEntry('plant_parts[]', image.plantPart));
      formData.files.add(MapEntry('images[]', await _multipartImage(image)));
    }

    return formData;
  }

  Future<MultipartFile> _multipartImage(
    CapturedPlantPartImage capturedImage,
  ) async {
    if (!kIsWeb && capturedImage.imagePath.isNotEmpty) {
      try {
        return await MultipartFile.fromFile(
          capturedImage.imagePath,
          filename: capturedImage.fileName,
        );
      } catch (_) {
        // Fall back to bytes if the picked file path is not readable.
      }
    }

    return MultipartFile.fromBytes(
      capturedImage.previewBytes,
      filename: capturedImage.fileName,
    );
  }
}
