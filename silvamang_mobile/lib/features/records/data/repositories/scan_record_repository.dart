import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../../shared/models/prediction_model.dart';
import '../../../../shared/models/scan_record_model.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../../../capture/data/repositories/scan_image_repository.dart';
import '../../../identification/data/models/mock_identification_result.dart';
import '../../../measurement/data/models/field_distance_measurement.dart';

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

  Future<ScanRecordModel> getScanRecordById(String id) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/scan-records/$id',
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) {
      return ScanRecordModel.fromJson(data);
    }
    return ScanRecordModel.fromJson(response.data ?? {});
  }

  Future<ScanRecordModel> validateScanRecordLocation(
    String scanRecordId,
  ) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/scan-records/$scanRecordId/validate-location',
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) {
      return ScanRecordModel.fromJson(data);
    }
    return ScanRecordModel.fromJson(response.data ?? {});
  }

  Future<int> uploadCapturedImagesToRecord({
    required String scanRecordId,
    required List<CapturedPlantPartImage> capturedImages,
  }) async {
    var uploadedCount = 0;

    for (final capturedImage in capturedImages) {
      await scanImageRepository.uploadScanImage(
        scanRecordId: scanRecordId,
        capturedImage: capturedImage,
      );
      uploadedCount++;
    }

    return uploadedCount;
  }

  Future<void> storeMeasurementForRecord({
    required String scanRecordId,
    required MockIdentificationResult result,
    DateTime? measuredAt,
    String notes = 'Manual calibrated measurement attached to scan result.',
  }) async {
    if (!_hasMeasurementEstimate(result)) {
      return;
    }

    await apiClient.post<Map<String, dynamic>>(
      '/measurements',
      data: {
        'scan_record_id': scanRecordId,
        'height_m': _finiteOrNull(result.heightM),
        'canopy_width_m': _finiteOrNull(result.canopyWidthM),
        'dbh_cm': _finiteOrNull(result.dbhCm),
        'measurement_method': result.measurementMethod,
        'confidence': _finiteOrNull(result.measurementConfidence),
        'notes': notes,
        'measured_at': (measuredAt ?? DateTime.now()).toIso8601String(),
      },
    );
  }

  Future<ScanRecordModel> createScanRecordFromMock({
    required MockIdentificationResult result,
    List<CapturedPlantPartImage> capturedImages = const [],
    double? locationAccuracy,
    String? locationLookupStatus,
    String? locationSource,
    DateTime? locationCapturedAt,
    String? manualBarangay,
    FieldDistanceMeasurement? fieldDistanceMeasurement,
  }) async {
    final capturedAt = (locationCapturedAt ?? DateTime.now()).toIso8601String();
    final resolvedLocationName = _resolvedLocationName(
      locationName: result.locationName,
      barangay: result.barangay,
      manualBarangay: manualBarangay,
    );
    final cleanManualBarangay = _cleanString(manualBarangay);
    final hasMeasurementEstimate = _hasMeasurementEstimate(result);
    final scanData = <String, dynamic>{
      'top_scientific_name': result.scientificName,
      'top_common_name': result.commonName,
      'species_id': result.speciesId,
      'confidence': _finiteOrNull(result.confidence),
      'capture_mode': result.captureMode,
      'identification_status': 'completed',
      'validation_status': 'pending',
      'latitude': result.latitude,
      'longitude': result.longitude,
      if (_finiteOrNull(locationAccuracy) != null)
        'accuracy': _finiteOrNull(locationAccuracy),
      'location_name': resolvedLocationName,
      'address': result.address,
      if (_cleanString(result.barangay) != null)
        'barangay': _cleanString(result.barangay),
      if (_cleanString(locationLookupStatus) != null)
        'location_lookup_status': _cleanString(locationLookupStatus),
      if (hasMeasurementEstimate && _finiteOrNull(result.heightM) != null)
        'height_m': _finiteOrNull(result.heightM),
      if (hasMeasurementEstimate && _finiteOrNull(result.canopyWidthM) != null)
        'canopy_width_m': _finiteOrNull(result.canopyWidthM),
      'notes': _scanNotes(
        barangay: result.barangay,
        manualBarangay: manualBarangay,
        locationAccuracy: locationAccuracy,
        locationLookupStatus: locationLookupStatus,
        locationSource: locationSource,
        fieldDistanceMeasurement: fieldDistanceMeasurement,
      ),
      'captured_at': capturedAt,
    };

    if (cleanManualBarangay != null) {
      scanData['manual_barangay'] = cleanManualBarangay;
    }

    final response = await apiClient.post<Map<String, dynamic>>(
      '/scan-records',
      data: scanData,
    );

    final data = response.data?['data'];
    final createdRecord = data is Map<String, dynamic>
        ? ScanRecordModel.fromJson(data)
        : ScanRecordModel.fromJson(response.data ?? {});
    final scanRecordId = createdRecord.id;

    if (scanRecordId.isEmpty) {
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
            'model_name': _predictionModelName(prediction),
            'model_version': _predictionModelVersion(prediction),
          },
        );
      }

      if (hasMeasurementEstimate) {
        await apiClient.post<Map<String, dynamic>>(
          '/measurements',
          data: {
            'scan_record_id': scanRecordId,
            'height_m': _finiteOrNull(result.heightM),
            'canopy_width_m': _finiteOrNull(result.canopyWidthM),
            'dbh_cm': _finiteOrNull(result.dbhCm),
            'measurement_method': result.measurementMethod,
            'confidence': _finiteOrNull(result.measurementConfidence),
            'notes': 'Measurement estimate attached to CNN scan result.',
            'measured_at': capturedAt,
          },
        );
      }

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

  Future<ScanRecordModel> createScanRecordFromOfflinePayload(
    Map<String, dynamic> payload,
  ) async {
    final scan = _asMap(payload['scan_record']);
    final response = await apiClient.post<Map<String, dynamic>>(
      '/scan-records',
      data: scan,
    );

    final data = response.data?['data'];
    final createdRecord = data is Map<String, dynamic>
        ? ScanRecordModel.fromJson(data)
        : ScanRecordModel.fromJson(response.data ?? {});
    final scanRecordId = createdRecord.id;

    if (scanRecordId.isEmpty) {
      throw const ApiException(
        'Scan record was created but no record ID was returned.',
      );
    }

    for (final prediction in _asList(payload['predictions'])) {
      await apiClient.post<Map<String, dynamic>>(
        '/predictions',
        data: {...prediction, 'scan_record_id': scanRecordId},
      );
    }

    final measurement = _asMap(payload['measurement']);
    if (measurement.isNotEmpty) {
      await apiClient.post<Map<String, dynamic>>(
        '/measurements',
        data: {...measurement, 'scan_record_id': scanRecordId},
      );
    }

    try {
      return await validateScanRecordLocation(scanRecordId);
    } catch (_) {
      return getScanRecordById(scanRecordId);
    }
  }

  Future<ScanRecordModel> getValidatedScanRecordOrCurrent(
    String scanRecordId,
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

  String _scanNotes({
    String? barangay,
    String? manualBarangay,
    double? locationAccuracy,
    String? locationLookupStatus,
    String? locationSource,
    FieldDistanceMeasurement? fieldDistanceMeasurement,
  }) {
    final notes = <String>[
      'SILVAMANG CNN identification result.',
      if (barangay != null && barangay.trim().isNotEmpty)
        'Barangay: $barangay.',
      if (manualBarangay != null && manualBarangay.trim().isNotEmpty)
        'Manual barangay note: $manualBarangay.',
      if (locationAccuracy != null)
        'GPS accuracy: ${locationAccuracy.toStringAsFixed(1)} meters.',
      if (locationLookupStatus != null &&
          locationLookupStatus.trim().isNotEmpty)
        'Barangay lookup: $locationLookupStatus',
      if (locationSource != null && locationSource.trim().isNotEmpty)
        'Location source: $locationSource.',
      if (fieldDistanceMeasurement?.distanceMeters != null)
        'Estimated field distance: ${fieldDistanceMeasurement!.distanceMeters!.toStringAsFixed(2)} meters.',
      if (fieldDistanceMeasurement?.distanceSource.isNotEmpty == true)
        'Distance source: ${fieldDistanceMeasurement!.distanceSource}.',
      if (fieldDistanceMeasurement?.distanceReliability.isNotEmpty == true)
        'Distance reliability: ${fieldDistanceMeasurement!.distanceReliability}.',
      if (fieldDistanceMeasurement?.warningMessage != null)
        'Distance accuracy note: ${fieldDistanceMeasurement!.warningMessage}.',
    ];

    return notes.join(' ');
  }

  String _resolvedLocationName({
    required String locationName,
    String? barangay,
    String? manualBarangay,
  }) {
    final resolvedBarangay = barangay?.trim();
    if (resolvedBarangay != null && resolvedBarangay.isNotEmpty) {
      return 'Barangay $resolvedBarangay';
    }

    final manual = manualBarangay?.trim();
    if (manual != null && manual.isNotEmpty) {
      return 'Barangay $manual';
    }

    final cleanLocationName = locationName.trim();
    return cleanLocationName.isEmpty
        ? 'GPS captured location'
        : cleanLocationName;
  }

  bool _hasMeasurementEstimate(MockIdentificationResult result) {
    return _hasMeasurementValue(result.heightM) ||
        _hasMeasurementValue(result.canopyWidthM) ||
        _finiteOrNull(result.dbhCm) != null;
  }

  bool _hasMeasurementValue(double? value) {
    final finiteValue = _finiteOrNull(value);
    return finiteValue != null && finiteValue > 0;
  }

  double? _finiteOrNull(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }

    return value;
  }

  String? _cleanString(String? value) {
    final cleanValue = value?.trim();

    return cleanValue == null || cleanValue.isEmpty ? null : cleanValue;
  }

  String _predictionModelName(PredictionModel prediction) {
    final modelName = prediction.modelName.trim();

    return modelName.isEmpty ? 'SILVAMANG EfficientNet-B0' : modelName;
  }

  String _predictionModelVersion(PredictionModel prediction) {
    final modelVersion = prediction.modelVersion.trim();

    return modelVersion.isEmpty ? 'transfer-learning-0.1.0' : modelVersion;
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
    }
    return const {};
  }

  List<Map<String, dynamic>> _asList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) =>
              item.map((key, mapValue) => MapEntry(key.toString(), mapValue)),
        )
        .toList();
  }
}
