import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../../shared/models/scan_record_model.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../../../capture/data/repositories/scan_image_repository.dart';
import '../../../identification/data/models/mock_identification_result.dart';

final scanRecordRepositoryProvider = Provider<ScanRecordRepository>((ref) {
  return ScanRecordRepository(
    apiClient: ApiClient.instance,
    scanImageRepository: ref.watch(scanImageRepositoryProvider),
  );
});

class ScanRecordRepository {
  const ScanRecordRepository({
    required this.apiClient,
    required this.scanImageRepository,
  });

  final ApiClient apiClient;
  final ScanImageRepository scanImageRepository;

  Future<List<ScanRecordModel>> getScanRecords({
    String? search,
    String? identificationStatus,
    String? validationStatus,
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (identificationStatus != null && identificationStatus.isNotEmpty)
        'identification_status': identificationStatus,
      if (validationStatus != null && validationStatus.isNotEmpty)
        'validation_status': validationStatus,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
    };

    final response = await apiClient.get<Map<String, dynamic>>(
      '/scan-records',
      query: query,
    );
    final items = _extractList(response.data);
    return items.map(ScanRecordModel.fromJson).toList();
  }

  Future<ScanRecordModel> getScanRecordById(int id) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/scan-records/$id',
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) {
      return ScanRecordModel.fromJson(data);
    }
    return ScanRecordModel.fromJson(response.data ?? {});
  }

  Future<ScanRecordModel> validateScanRecordLocation(int scanRecordId) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/scan-records/$scanRecordId/validate-location',
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) {
      return ScanRecordModel.fromJson(data);
    }
    return ScanRecordModel.fromJson(response.data ?? {});
  }

  Future<ScanRecordModel> createScanRecordFromMock({
    required MockIdentificationResult result,
    List<CapturedPlantPartImage> capturedImages = const [],
  }) async {
    final now = DateTime.now().toIso8601String();
    final response = await apiClient.post<Map<String, dynamic>>(
      '/scan-records',
      data: {
        'top_scientific_name': result.scientificName,
        'top_common_name': result.commonName,
        'species_id': result.speciesId,
        'confidence': result.confidence,
        'capture_mode': result.captureMode,
        'identification_status': 'completed',
        'validation_status': 'pending',
        'latitude': result.latitude,
        'longitude': result.longitude,
        'location_name': result.locationName,
        'address': result.address,
        'notes': 'Mock identification result from Phase 8C.',
        'captured_at': now,
      },
    );

    final data = response.data?['data'];
    final createdRecord = data is Map<String, dynamic>
        ? ScanRecordModel.fromJson(data)
        : ScanRecordModel.fromJson(response.data ?? {});
    final scanRecordId = createdRecord.id;

    if (scanRecordId == 0) {
      throw const ApiException(
        'Scan record was created but no record ID was returned.',
      );
    }

    try {
      for (final prediction in result.predictions) {
        await apiClient.post<Map<String, dynamic>>(
          '/predictions',
          data: {
            'scan_record_id': scanRecordId,
            'rank': prediction.rank,
            'scientific_name': prediction.scientificName,
            'common_name': prediction.commonName,
            'confidence': prediction.confidence,
            'model_name': 'SILVAMANG Mock Classifier',
            'model_version': '0.1.0',
          },
        );
      }

      await apiClient.post<Map<String, dynamic>>(
        '/measurements',
        data: {
          'scan_record_id': scanRecordId,
          'height_m': result.heightM,
          'canopy_width_m': result.canopyWidthM,
          'dbh_cm': result.dbhCm,
          'measurement_method': 'depth_estimation',
          'confidence': result.measurementConfidence,
          'notes': 'Mock measurement from Phase 8C.',
          'measured_at': now,
        },
      );

      for (final capturedImage in capturedImages) {
        await scanImageRepository.uploadScanImage(
          scanRecordId: scanRecordId,
          capturedImage: capturedImage,
        );
      }
    } catch (error) {
      throw ApiException(
        'Scan record saved, but related data or selected images could not be saved: $error',
      );
    }

    try {
      return await validateScanRecordLocation(scanRecordId);
    } catch (_) {
      try {
        return await getScanRecordById(scanRecordId);
      } catch (_) {
        return createdRecord;
      }
    }
  }

  Future<ScanRecordModel> getValidatedScanRecordOrCurrent(
    int scanRecordId,
  ) async {
    try {
      return await validateScanRecordLocation(scanRecordId);
    } catch (_) {
      return getScanRecordById(scanRecordId);
    }
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? responseData) {
    final data = responseData?['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}
