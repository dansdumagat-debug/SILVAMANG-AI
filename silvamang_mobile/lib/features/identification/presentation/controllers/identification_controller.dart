import 'package:flutter_riverpod/legacy.dart';

import '../../../../shared/models/scan_record_model.dart';
import '../../../capture/data/models/captured_plant_part_image.dart';
import '../../../records/data/repositories/scan_record_repository.dart';
import '../../data/models/mock_ai_prediction_response.dart';
import '../../data/models/mock_identification_result.dart';
import '../../data/repositories/mock_ai_prediction_repository.dart';

final identificationControllerProvider =
    StateNotifierProvider<IdentificationController, IdentificationState>((ref) {
      return IdentificationController(
        scanRecordRepository: ref.watch(scanRecordRepositoryProvider),
        predictionRepository: ref.watch(mockAiPredictionRepositoryProvider),
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
    bool clearMessages = false,
  }) {
    return IdentificationState(
      predictionResponse: predictionResponse ?? this.predictionResponse,
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
    );
  }
}

class IdentificationController extends StateNotifier<IdentificationState> {
  IdentificationController({
    required this.scanRecordRepository,
    required this.predictionRepository,
  }) : super(const IdentificationState());

  final ScanRecordRepository scanRecordRepository;
  final MockAiPredictionRepository predictionRepository;

  Future<void> runMockPrediction({
    required List<CapturedPlantPartImage> capturedImages,
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
  }) async {
    state = state.copyWith(isPredicting: true, clearMessages: true);
    try {
      final response = await predictionRepository.predict(
        capturedImages: capturedImages,
        latitude: latitude,
        longitude: longitude,
      );
      state = state.copyWith(
        predictionResponse: response,
        result: MockIdentificationResult.fromMockAiResponse(
          response,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          address: address,
        ),
        isPredicting: false,
      );
    } catch (_) {
      state = state.copyWith(
        isPredicting: false,
        warningMessage:
            'Using local mock prediction because the server prediction failed.',
      );
    }
  }

  Future<void> saveCurrentResult({
    List<CapturedPlantPartImage> capturedImages = const [],
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
    bool isUsingFallback = false,
  }) async {
    state = state.copyWith(
      isSaving: true,
      uploadedImagesCount: 0,
      clearMessages: true,
    );
    try {
      final resultWithLocation = state.result.copyWith(
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        address: address,
      );
      final record = await scanRecordRepository.createScanRecordFromMock(
        result: resultWithLocation,
        capturedImages: capturedImages,
      );
      final uploadedCount = record.images.isNotEmpty
          ? record.images.length
          : capturedImages.length;
      state = state.copyWith(
        savedRecord: record,
        isSaving: false,
        uploadedImagesCount: uploadedCount,
        successMessage: isUsingFallback
            ? 'Scan record saved using fallback location.'
            : 'Scan record, GPS location, and selected images saved successfully.',
        warningMessage: isUsingFallback
            ? 'GPS unavailable. Fallback prototype location will be used.'
            : null,
      );
    } catch (error) {
      state = state.copyWith(isSaving: false, errorMessage: error.toString());
    }
  }

  Future<void> saveMockResult({
    List<CapturedPlantPartImage> capturedImages = const [],
    double? latitude,
    double? longitude,
    String? locationName,
    String? address,
    bool isUsingFallback = false,
  }) {
    return saveCurrentResult(
      capturedImages: capturedImages,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      address: address,
      isUsingFallback: isUsingFallback,
    );
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }
}
