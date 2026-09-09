import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../shared/models/prediction_model.dart';
import '../../../../shared/models/scan_record_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../../../map/data/models/map_scan_record.dart';
import '../../../map/data/repositories/local_map_scan_repository.dart';
import '../../../measurement/data/models/field_distance_measurement.dart';
import '../../../measurements/data/models/camera_measurement_result.dart';
import '../../../measurements/presentation/controllers/camera_measurement_controller.dart';
import '../../../offline_sync/data/models/offline_sync_item.dart';
import '../../../offline_sync/data/repositories/offline_sync_repository.dart';
import '../../../records/data/repositories/scan_record_repository.dart';
import '../../data/models/mock_ai_prediction_response.dart';
import '../../data/models/mock_identification_result.dart';
import '../../data/repositories/mock_ai_prediction_repository.dart';

final identificationControllerProvider =
    StateNotifierProvider<IdentificationController, IdentificationState>((ref) {
      final authState = ref.watch(authControllerProvider);
      return IdentificationController(
        scanRecordRepository: ref.watch(scanRecordRepositoryProvider),
        predictionRepository: ref.watch(mockAiPredictionRepositoryProvider),
        offlineSyncRepository: ref.watch(offlineSyncRepositoryProvider),
        localMapScanRepository: ref.watch(localMapScanRepositoryProvider),
        connectivityService: const ConnectivityService(),
        currentUserId: null,
        currentUserEmail: authState.user?.email,
      );
    });

class IdentificationState {
  const IdentificationState({
    this.predictionResponse,
    this.result = MockIdentificationResult.sample,
    this.savedRecord,
    this.isPredicting = false,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
    this.warningMessage,
    this.uploadedImagesCount = 0,
    this.offlineModeEnabled = false,
  });

  final MockAiPredictionResponse? predictionResponse;
  final MockIdentificationResult result;
  final ScanRecordModel? savedRecord;
  final bool isPredicting;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;
  final String? warningMessage;
  final int uploadedImagesCount;
  final bool offlineModeEnabled;
  bool get hasValidAiResult => predictionResponse?.isValidCnnResult ?? false;

  IdentificationState copyWith({
    MockAiPredictionResponse? predictionResponse,
    MockIdentificationResult? result,
    ScanRecordModel? savedRecord,
    bool? isPredicting,
    bool? isSaving,
    String? errorMessage,
    String? successMessage,
    String? warningMessage,
    int? uploadedImagesCount,
    bool? offlineModeEnabled,
    bool clearMessages = false,
    bool clearPrediction = false,
  }) {
    return IdentificationState(
      predictionResponse: clearPrediction
          ? null
          : predictionResponse ?? this.predictionResponse,
      result: result ?? this.result,
      savedRecord: savedRecord ?? this.savedRecord,
      isPredicting: isPredicting ?? this.isPredicting,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      successMessage: clearMessages
          ? null
          : successMessage ?? this.successMessage,
      warningMessage: clearMessages
          ? null
          : warningMessage ?? this.warningMessage,
      uploadedImagesCount: uploadedImagesCount ?? this.uploadedImagesCount,
      offlineModeEnabled: offlineModeEnabled ?? this.offlineModeEnabled,
    );
  }
}

class IdentificationController extends StateNotifier<IdentificationState> {
  IdentificationController({
    required this.scanRecordRepository,
    required this.predictionRepository,
    required this.offlineSyncRepository,
    required this.localMapScanRepository,
    required this.connectivityService,
    this.currentUserId,
    this.currentUserEmail,
  }) : super(const IdentificationState());

  final ScanRecordRepository scanRecordRepository;
  final MockAiPredictionRepository predictionRepository;
  final OfflineSyncRepository offlineSyncRepository;
  final LocalMapScanRepository localMapScanRepository;
  final ConnectivityService connectivityService;
  final String? currentUserId;
  final String? currentUserEmail;

  Future<void> runMockPrediction({
    required List<CapturedPlantPartImage> capturedImages,
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
    String? barangay,
    FieldDistanceMeasurement? fieldDistanceMeasurement,
  }) async {
    state = state.copyWith(isPredicting: true, clearMessages: true);
    if (capturedImages.isEmpty) {
      state = state.copyWith(
        isPredicting: false,
        clearPrediction: true,
        errorMessage:
            'No image selected. Please capture or select an image first.',
      );
      return;
    }

    try {
      final response = await predictionRepository.predict(
        capturedImages: capturedImages,
        latitude: latitude,
        longitude: longitude,
        subjectDistanceM: fieldDistanceMeasurement?.distanceMeters,
        forceOffline: state.offlineModeEnabled,
      );
      state = state.copyWith(
        predictionResponse: response,
        result: MockIdentificationResult.fromMockAiResponse(
          response,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          address: address,
          barangay: barangay,
        ),
        isPredicting: false,
        warningMessage: response.warning,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        isPredicting: false,
        clearPrediction: true,
        errorMessage: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isPredicting: false,
        clearPrediction: true,
        errorMessage:
            'Prediction failed. Please check the image and try again.',
      );
    }
  }

  Future<void> saveCurrentResult({
    List<CapturedPlantPartImage> capturedImages = const [],
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
    String? barangay,
    String? manualBarangay,
    double? locationAccuracy,
    DateTime? locationCapturedAt,
    String? barangayStatus,
    String? locationSource,
    FieldDistanceMeasurement? fieldDistanceMeasurement,
    CameraMeasurementSelection? cameraMeasurementSelection,
    CameraMeasurementResult? cameraMeasurementResult,
    bool isUsingFallback = false,
  }) async {
    if (capturedImages.isEmpty || !state.hasValidAiResult) {
      state = state.copyWith(
        isSaving: false,
        errorMessage:
            'Please capture or select an image and wait for a valid CNN prediction before saving.',
        clearMessages: true,
      );
      return;
    }

    state = state.copyWith(
      isSaving: true,
      uploadedImagesCount: 0,
      clearMessages: true,
    );
    try {
      final selectedMeasurements = _selectedMeasurements(
        cameraMeasurementSelection,
        cameraMeasurementResult,
      );
      final resultWithLocation =
          _resultWithManualMeasurements(
            state.result,
            selectedMeasurements,
          ).copyWith(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            address: address,
            barangay: barangay,
          );

      final isOnline = await connectivityService.isOnline();
      if (!isOnline) {
        await _queueOfflineSave(
          result: resultWithLocation,
          capturedImages: capturedImages,
          locationAccuracy: locationAccuracy,
          locationCapturedAt: locationCapturedAt,
          barangayStatus: barangayStatus,
          locationSource: locationSource,
          manualBarangay: manualBarangay,
          fieldDistanceMeasurement: fieldDistanceMeasurement,
          successMessage:
              'You are offline. Scan was saved to the offline queue.',
        );
        await _saveLocalMapScanRecord(
          result: resultWithLocation,
          capturedImages: capturedImages,
          locationAccuracy: locationAccuracy,
          locationLookupStatus: barangayStatus,
          locationSource: locationSource,
          locationCapturedAt: locationCapturedAt,
          manualBarangay: manualBarangay,
          fieldDistanceMeasurement: fieldDistanceMeasurement,
          syncStatus: MapScanRecord.pending,
        );
        return;
      }

      final serverScanRecordId = state.predictionResponse?.serverScanRecordId;
      if (serverScanRecordId != null) {
        final uploadedCount = await scanRecordRepository
            .uploadCapturedImagesToRecord(
              scanRecordId: serverScanRecordId,
              capturedImages: capturedImages,
            );
        if (selectedMeasurements.hasAny) {
          await scanRecordRepository.storeMeasurementForRecord(
            scanRecordId: serverScanRecordId,
            result: resultWithLocation,
            measuredAt: locationCapturedAt,
          );
        }
        final record = await scanRecordRepository
            .getValidatedScanRecordOrCurrent(serverScanRecordId);
        await _saveLocalMapScanRecord(
          result: resultWithLocation,
          capturedImages: capturedImages,
          locationAccuracy: locationAccuracy,
          locationLookupStatus: barangayStatus,
          locationSource: locationSource,
          locationCapturedAt: locationCapturedAt,
          manualBarangay: manualBarangay,
          fieldDistanceMeasurement: fieldDistanceMeasurement,
          syncStatus: MapScanRecord.synced,
          serverId: serverScanRecordId,
        );
        state = state.copyWith(
          savedRecord: record,
          isSaving: false,
          uploadedImagesCount: uploadedCount,
          successMessage:
              'AI scan record, GPS location, and selected images saved successfully.',
          warningMessage: null,
        );
        return;
      }

      final record = await scanRecordRepository.createScanRecordFromMock(
        result: resultWithLocation,
        capturedImages: capturedImages,
        locationAccuracy: locationAccuracy,
        locationLookupStatus: barangayStatus,
        locationSource: locationSource,
        locationCapturedAt: locationCapturedAt,
        manualBarangay: manualBarangay,
        fieldDistanceMeasurement: fieldDistanceMeasurement,
      );
      await _saveLocalMapScanRecord(
        result: resultWithLocation,
        capturedImages: capturedImages,
        locationAccuracy: locationAccuracy,
        locationLookupStatus: barangayStatus,
        locationSource: locationSource,
        locationCapturedAt: locationCapturedAt,
        manualBarangay: manualBarangay,
        fieldDistanceMeasurement: fieldDistanceMeasurement,
        syncStatus: MapScanRecord.synced,
        serverId: record.id.isEmpty ? null : record.id,
      );
      final uploadedCount = record.images.isNotEmpty
          ? record.images.length
          : capturedImages.length;
      final hasScanLocation = latitude != null && longitude != null;
      state = state.copyWith(
        savedRecord: record,
        isSaving: false,
        uploadedImagesCount: uploadedCount,
        successMessage: hasScanLocation
            ? 'Scan record, GPS location, and selected images saved successfully.'
            : 'Scan record and selected images saved. GPS location was unavailable.',
        warningMessage: hasScanLocation
            ? null
            : 'GPS unavailable. No fake or demo coordinates were saved.',
      );
    } catch (_) {
      final selectedMeasurements = _selectedMeasurements(
        cameraMeasurementSelection,
        cameraMeasurementResult,
      );
      final failedResultWithLocation =
          _resultWithManualMeasurements(
            state.result,
            selectedMeasurements,
          ).copyWith(
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            address: address,
            barangay: barangay,
          );
      await _queueOfflineSave(
        result: failedResultWithLocation,
        capturedImages: capturedImages,
        locationAccuracy: locationAccuracy,
        locationCapturedAt: locationCapturedAt,
        barangayStatus: barangayStatus,
        locationSource: locationSource,
        manualBarangay: manualBarangay,
        fieldDistanceMeasurement: fieldDistanceMeasurement,
        successMessage:
            'Server unavailable. Scan was saved to the offline queue.',
      );
      await _saveLocalMapScanRecord(
        result: failedResultWithLocation,
        capturedImages: capturedImages,
        locationAccuracy: locationAccuracy,
        locationLookupStatus: barangayStatus,
        locationSource: locationSource,
        locationCapturedAt: locationCapturedAt,
        manualBarangay: manualBarangay,
        fieldDistanceMeasurement: fieldDistanceMeasurement,
        syncStatus: MapScanRecord.pending,
      );
    }
  }

  CameraMeasurementSelection _selectedMeasurements(
    CameraMeasurementSelection? selection,
    CameraMeasurementResult? fallbackResult,
  ) {
    final selected = selection;
    if (selected != null) {
      return selected;
    }

    final result = fallbackResult;
    if (result == null) {
      return const CameraMeasurementSelection();
    }

    return const CameraMeasurementSelection().select(result);
  }

  MockIdentificationResult _resultWithManualMeasurements(
    MockIdentificationResult result,
    CameraMeasurementSelection cameraMeasurementSelection,
  ) {
    final heightResult = cameraMeasurementSelection.heightResult;
    final canopyResult = cameraMeasurementSelection.canopyWidthResult;
    if (!_isUsableManualMeasurement(heightResult) &&
        !_isUsableManualMeasurement(canopyResult)) {
      return result;
    }

    return result.copyWith(
      heightM: _isUsableManualMeasurement(heightResult)
          ? heightResult!.estimatedValueM
          : result.heightM,
      canopyWidthM: _isUsableManualMeasurement(canopyResult)
          ? canopyResult!.estimatedValueM
          : result.canopyWidthM,
      measurementMethod: _manualMeasurementMethod(
        heightResult,
        canopyResult,
        result.measurementMethod,
      ),
      measurementConfidence: _manualMeasurementConfidence(
        heightResult,
        canopyResult,
        result.measurementConfidence,
      ),
      explanation: result.explanation.isEmpty
          ? 'Manual measurement attached.'
          : '${result.explanation} Manual measurement attached.',
    );
  }

  bool _isUsableManualMeasurement(CameraMeasurementResult? result) {
    return result != null &&
        result.estimatedValueM.isFinite &&
        result.estimatedValueM > 0;
  }

  String _manualMeasurementMethod(
    CameraMeasurementResult? heightResult,
    CameraMeasurementResult? canopyResult,
    String fallback,
  ) {
    final heightMethod = _isUsableManualMeasurement(heightResult)
        ? heightResult!.methodUsed
        : null;
    final canopyMethod = _isUsableManualMeasurement(canopyResult)
        ? canopyResult!.methodUsed
        : null;
    if (heightMethod != null && canopyMethod != null) {
      return heightMethod == canopyMethod ? heightMethod : 'manual_mixed';
    }

    return heightMethod ?? canopyMethod ?? fallback;
  }

  double _manualMeasurementConfidence(
    CameraMeasurementResult? heightResult,
    CameraMeasurementResult? canopyResult,
    double fallback,
  ) {
    final values = [
      if (_isUsableManualMeasurement(heightResult))
        _confidenceFromManualReliability(heightResult!),
      if (_isUsableManualMeasurement(canopyResult))
        _confidenceFromManualReliability(canopyResult!),
    ];
    if (values.isEmpty) {
      return fallback;
    }

    return values.reduce((total, value) => total + value) / values.length;
  }

  double _confidenceFromManualReliability(CameraMeasurementResult result) {
    if (result.methodUsed == 'calibrated_reference_object') {
      return 92;
    }

    if (result.distanceSource == 'manual_input') {
      return 88;
    }

    if (result.distanceSource == 'gps_walk_measurement') {
      return 74;
    }

    return 60;
  }

  Future<void> _saveLocalMapScanRecord({
    required MockIdentificationResult result,
    List<CapturedPlantPartImage> capturedImages = const [],
    double? locationAccuracy,
    DateTime? locationCapturedAt,
    String? locationLookupStatus,
    String? locationSource,
    String? manualBarangay,
    FieldDistanceMeasurement? fieldDistanceMeasurement,
    required String syncStatus,
    String? serverId,
  }) async {
    try {
      final now = DateTime.now();
      final createdAt = locationCapturedAt ?? now;
      await localMapScanRepository.saveLocalRecord(
        MapScanRecord(
          localId: serverId == null
              ? 'local_${now.microsecondsSinceEpoch}'
              : 'server_$serverId',
          serverId: serverId,
          userId: currentUserId,
          userEmail: currentUserEmail,
          speciesName: result.scientificName,
          commonName: result.commonName,
          confidence: _finiteOrNull(result.confidence),
          imagePath: _firstValidImagePath(capturedImages),
          latitude: result.latitude,
          longitude: result.longitude,
          accuracy: _finiteOrNull(locationAccuracy),
          barangay: result.barangay,
          manualBarangay: _cleanManualBarangay(manualBarangay),
          locationLookupStatus: locationLookupStatus,
          locationSource: locationSource,
          heightM: _finiteOrNull(result.heightM),
          canopyWidthM: _finiteOrNull(result.canopyWidthM),
          fieldDistanceM: _finiteOrNull(
            fieldDistanceMeasurement?.distanceMeters,
          ),
          notes: result.explanation,
          syncStatus: syncStatus,
          createdAt: createdAt,
          updatedAt: now,
        ),
      );
    } catch (_) {
      // Local map pin storage must not block the primary Save Record flow.
    }
  }

  String? _firstValidImagePath(List<CapturedPlantPartImage> capturedImages) {
    for (final image in capturedImages) {
      final imagePath = image.imagePath.trim();
      if (imagePath.isNotEmpty) {
        return imagePath;
      }
    }

    return null;
  }

  String? _cleanManualBarangay(String? value) {
    final cleanValue = value?.trim();
    return cleanValue == null || cleanValue.isEmpty ? null : cleanValue;
  }

  double? _finiteOrNull(double? value) {
    if (value == null || !value.isFinite) {
      return null;
    }

    return value;
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

  bool _isPredictionSaveable(PredictionModel prediction) {
    return prediction.scientificName.trim().isNotEmpty &&
        _finiteOrNull(prediction.confidence) != null;
  }

  String _predictionModelName(PredictionModel prediction) {
    final modelName = prediction.modelName.trim();

    return modelName.isEmpty ? 'SILVAMANG EfficientNet-B0' : modelName;
  }

  String _predictionModelVersion(PredictionModel prediction) {
    final modelVersion = prediction.modelVersion.trim();

    return modelVersion.isEmpty ? 'transfer-learning-0.1.0' : modelVersion;
  }

  Future<void> _queueOfflineSave({
    required MockIdentificationResult result,
    List<CapturedPlantPartImage> capturedImages = const [],
    double? locationAccuracy,
    DateTime? locationCapturedAt,
    String? barangayStatus,
    String? locationSource,
    String? manualBarangay,
    FieldDistanceMeasurement? fieldDistanceMeasurement,
    required String successMessage,
  }) async {
    final now = DateTime.now();
    final scanCapturedAt = locationCapturedAt ?? now;
    final offlineLocationNote = [
      'Offline queued scan.',
      'Image upload requires internet connection and will be finalized during sync.',
      if (result.barangay != null && result.barangay!.trim().isNotEmpty)
        'Barangay: ${result.barangay}.',
      if (manualBarangay != null && manualBarangay.trim().isNotEmpty)
        'Manual barangay note: $manualBarangay.',
      if (locationAccuracy != null)
        'GPS accuracy: ${locationAccuracy.toStringAsFixed(1)} meters.',
      if (barangayStatus != null && barangayStatus.trim().isNotEmpty)
        'Barangay lookup: $barangayStatus',
      if (locationSource != null && locationSource.trim().isNotEmpty)
        'Location source: $locationSource.',
      if (fieldDistanceMeasurement?.distanceMeters != null)
        'Estimated field distance: ${fieldDistanceMeasurement!.distanceMeters!.toStringAsFixed(2)} meters.',
      if (fieldDistanceMeasurement?.distanceSource.isNotEmpty == true)
        'Distance source: ${fieldDistanceMeasurement!.distanceSource}.',
      if (fieldDistanceMeasurement?.distanceReliability.isNotEmpty == true)
        'Distance reliability: ${fieldDistanceMeasurement!.distanceReliability}.',
      if (fieldDistanceMeasurement?.warningMessage != null)
        'Distance warning: ${fieldDistanceMeasurement!.warningMessage}.',
    ].join(' ');
    final hasMeasurementEstimate = _hasMeasurementEstimate(result);
    final cleanBarangay = _cleanManualBarangay(result.barangay);
    final cleanManualBarangay = _cleanManualBarangay(manualBarangay);
    final cleanLookupStatus = _cleanManualBarangay(barangayStatus);
    final measurementPayload = hasMeasurementEstimate
        ? {
            'height_m': _finiteOrNull(result.heightM),
            'canopy_width_m': _finiteOrNull(result.canopyWidthM),
            'dbh_cm': _finiteOrNull(result.dbhCm),
            'measurement_method': result.measurementMethod,
            'confidence': _finiteOrNull(result.measurementConfidence),
            'notes': 'Offline queued measurement attached to CNN scan result.',
            'measured_at': now.toIso8601String(),
          }
        : <String, dynamic>{};
    final payload = {
      'scientific_name': result.scientificName,
      'common_name': result.commonName,
      'confidence': _finiteOrNull(result.confidence),
      'latitude': result.latitude,
      'longitude': result.longitude,
      'location_name': result.locationName,
      'address': result.address,
      'barangay': cleanBarangay,
      'manual_barangay': cleanManualBarangay,
      'accuracy_m': _finiteOrNull(locationAccuracy),
      'location_captured_at': scanCapturedAt.toIso8601String(),
      'barangay_lookup_status': cleanLookupStatus,
      'location_source': locationSource,
      'field_distance_m': _finiteOrNull(
        fieldDistanceMeasurement?.distanceMeters,
      ),
      'distance_source': fieldDistanceMeasurement?.distanceSource,
      'start_latitude': fieldDistanceMeasurement?.startPoint?.latitude,
      'start_longitude': fieldDistanceMeasurement?.startPoint?.longitude,
      'target_latitude': fieldDistanceMeasurement?.targetPoint?.latitude,
      'target_longitude': fieldDistanceMeasurement?.targetPoint?.longitude,
      'start_accuracy_m': _finiteOrNull(
        fieldDistanceMeasurement?.startPoint?.accuracyM,
      ),
      'target_accuracy_m': _finiteOrNull(
        fieldDistanceMeasurement?.targetPoint?.accuracyM,
      ),
      'distance_reliability': fieldDistanceMeasurement?.distanceReliability,
      'distance_warning': fieldDistanceMeasurement?.warningMessage,
      'distance_start_latitude': fieldDistanceMeasurement?.startPoint?.latitude,
      'distance_start_longitude':
          fieldDistanceMeasurement?.startPoint?.longitude,
      'distance_start_accuracy_m': _finiteOrNull(
        fieldDistanceMeasurement?.startPoint?.accuracyM,
      ),
      'distance_start_timestamp': fieldDistanceMeasurement
          ?.startPoint
          ?.timestamp
          .toIso8601String(),
      'distance_target_latitude':
          fieldDistanceMeasurement?.targetPoint?.latitude,
      'distance_target_longitude':
          fieldDistanceMeasurement?.targetPoint?.longitude,
      'distance_target_accuracy_m': _finiteOrNull(
        fieldDistanceMeasurement?.targetPoint?.accuracyM,
      ),
      'distance_target_timestamp': fieldDistanceMeasurement
          ?.targetPoint
          ?.timestamp
          .toIso8601String(),
      'distance_accuracy_note': fieldDistanceMeasurement?.warningMessage,
      // TODO: Add field distance columns to backend scan records.
      // TODO: Send location_status to Laravel once the endpoint supports it.
      'location_status': result.latitude != null && result.longitude != null
          ? 'captured'
          : 'unavailable',
      'created_at': now.toIso8601String(),
      'note':
          'Image upload requires internet connection and will be finalized during sync.',
      'scan_record': {
        'top_scientific_name': result.scientificName,
        'top_common_name': result.commonName,
        'species_id': result.speciesId,
        'confidence': _finiteOrNull(result.confidence),
        'capture_mode': result.captureMode,
        'identification_status': 'completed',
        'validation_status': 'pending',
        'latitude': result.latitude,
        'longitude': result.longitude,
        'accuracy': _finiteOrNull(locationAccuracy),
        'location_name': result.locationName,
        'address': result.address,
        'barangay': cleanBarangay,
        'manual_barangay': cleanManualBarangay,
        'location_lookup_status': cleanLookupStatus,
        if (hasMeasurementEstimate) ...{
          'height_m': _finiteOrNull(result.heightM),
          'canopy_width_m': _finiteOrNull(result.canopyWidthM),
        },
        'notes': offlineLocationNote,
        'captured_at': scanCapturedAt.toIso8601String(),
      },
      'predictions': result.predictions
          .where(_isPredictionSaveable)
          .map(
            (prediction) => {
              'rank': prediction.rank,
              'scientific_name': prediction.scientificName,
              'common_name': prediction.commonName,
              'confidence': _finiteOrNull(prediction.confidence),
              'model_name': _predictionModelName(prediction),
              'model_version': _predictionModelVersion(prediction),
            },
          )
          .toList(),
      'measurement': measurementPayload,
      'image_metadata': capturedImages
          .map(
            (image) => {
              'plant_part': image.plantPart,
              'file_name': image.fileName,
              'source': image.source,
              'captured_at': image.capturedAt.toIso8601String(),
              'note': 'Image bytes are not stored in Phase 21A queue.',
            },
          )
          .toList(),
    };

    await offlineSyncRepository.addItem(
      OfflineSyncItem(
        id: 'scan_${now.microsecondsSinceEpoch}',
        type: OfflineSyncItem.typeScanRecordMockSave,
        payloadJson: jsonEncode(payload),
        status: OfflineSyncItem.statusPending,
        createdAt: now,
      ),
    );

    state = state.copyWith(
      isSaving: false,
      uploadedImagesCount: 0,
      successMessage: successMessage,
      warningMessage:
          'Image upload requires internet connection and will be finalized during sync.',
    );
  }

  Future<void> saveMockResult({
    List<CapturedPlantPartImage> capturedImages = const [],
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
    String? barangay,
    String? manualBarangay,
    double? locationAccuracy,
    DateTime? locationCapturedAt,
    String? barangayStatus,
    String? locationSource,
    bool isUsingFallback = false,
  }) {
    return saveCurrentResult(
      capturedImages: capturedImages,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      address: address,
      barangay: barangay,
      manualBarangay: manualBarangay,
      locationAccuracy: locationAccuracy,
      locationCapturedAt: locationCapturedAt,
      barangayStatus: barangayStatus,
      locationSource: locationSource,
      isUsingFallback: isUsingFallback,
    );
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  void setOfflineMode(bool enabled) {
    state = state.copyWith(
      offlineModeEnabled: enabled,
      clearMessages: true,
      clearPrediction: true,
    );
  }
}
