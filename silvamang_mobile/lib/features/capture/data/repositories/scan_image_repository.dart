import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../../shared/models/scan_image_model.dart';
import '../models/captured_plant_part_image.dart';

final scanImageRepositoryProvider = Provider<ScanImageRepository>((ref) {
  return ScanImageRepository(apiClient: ApiClient.instance);
});

class ScanImageRepository {
  const ScanImageRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<ScanImageModel> uploadScanImage({
    required String scanRecordId,
    required CapturedPlantPartImage capturedImage,
  }) async {
    try {
      final multipartImage = await _multipartImage(capturedImage);
      final formData = FormData.fromMap({
        'scan_record_id': scanRecordId,
        'plant_part': capturedImage.plantPart,
        'image': multipartImage,
        'local_uri': capturedImage.imagePath,
      });

      final response = await apiClient.postForm<Map<String, dynamic>>(
        '/scan-images',
        data: formData,
      );
      final data = response.data?['data'];

      if (data is Map<String, dynamic>) {
        return ScanImageModel.fromJson(data);
      }

      return ScanImageModel.fromJson(response.data ?? {});
    } catch (_) {
      throw const ApiException(
        'Unable to upload selected image. Please try again.',
      );
    }
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
        // Fall back to preview bytes when a picked file path is unavailable.
      }
    }

    return MultipartFile.fromBytes(
      capturedImage.previewBytes,
      filename: capturedImage.fileName,
    );
  }
}
