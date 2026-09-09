import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../models/ai_measurement_response.dart';

final aiMeasurementRepositoryProvider = Provider<AiMeasurementRepository>((
  ref,
) {
  return AiMeasurementRepository(apiClient: ApiClient.instance);
});

class AiMeasurementRepository {
  const AiMeasurementRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<AiMeasurementData> measure({
    List<CapturedPlantPartImage> capturedImages = const [],
    String measurementType = 'tree_height',
    double? referenceHeightM,
    double? subjectDistanceM,
    double? referenceDistanceM,
    double? subjectPixelSpan,
    double? referencePixelSpan,
  }) async {
    try {
      final payload = <String, dynamic>{'measurement_type': measurementType};

      if (referenceHeightM != null) {
        payload['reference_height_m'] = referenceHeightM;
      }

      if (subjectDistanceM != null) {
        payload['subject_distance_m'] = subjectDistanceM;
      }

      if (referenceDistanceM != null) {
        payload['reference_distance_m'] = referenceDistanceM;
      }

      if (subjectPixelSpan != null) {
        payload['subject_pixel_span'] = subjectPixelSpan;
      }

      if (referencePixelSpan != null) {
        payload['reference_pixel_span'] = referencePixelSpan;
      }

      final Response<Map<String, dynamic>> response;
      if (capturedImages.isNotEmpty) {
        payload['image'] = await _multipartImageFrom(capturedImages.first);
        response = await apiClient.postForm<Map<String, dynamic>>(
          '/ai/measure',
          data: FormData.fromMap(payload),
        );
      } else {
        response = await apiClient.post<Map<String, dynamic>>(
          '/ai/measure',
          data: payload,
        );
      }

      final responseData = response.data ?? <String, dynamic>{};
      return AiMeasurementResponse.fromJson(responseData).data;
    } catch (_) {
      throw const ApiException(
        'Unable to get measurement result. Please try again.',
      );
    }
  }

  Future<MultipartFile> _multipartImageFrom(
    CapturedPlantPartImage image,
  ) async {
    try {
      if (image.imagePath.isNotEmpty && File(image.imagePath).existsSync()) {
        return MultipartFile.fromFile(
          image.imagePath,
          filename: image.fileName,
        );
      }
    } catch (_) {
      // Fall back to bytes below for platforms that cannot read the path.
    }

    return MultipartFile.fromBytes(
      image.previewBytes,
      filename: image.fileName.isEmpty ? 'mangrove-image.jpg' : image.fileName,
    );
  }
}
