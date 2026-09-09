import 'package:flutter_riverpod/legacy.dart';

import '../../../capture/data/models/captured_plant_part_image.dart';
import '../../data/models/ai_measurement_response.dart';
import '../../data/repositories/ai_measurement_repository.dart';

final measurementControllerProvider =
    StateNotifierProvider<MeasurementController, MeasurementState>((ref) {
      return MeasurementController(
        repository: ref.watch(aiMeasurementRepositoryProvider),
      );
    });

class MeasurementState {
  const MeasurementState({
    this.measurement,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final AiMeasurementData? measurement;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  MeasurementState copyWith({
    AiMeasurementData? measurement,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
    bool clearMeasurement = false,
  }) {
    return MeasurementState(
      measurement: clearMeasurement ? null : measurement ?? this.measurement,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      successMessage: clearMessages
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}

class MeasurementController extends StateNotifier<MeasurementState> {
  MeasurementController({required this.repository})
    : super(const MeasurementState());

  final AiMeasurementRepository repository;

  Future<void> loadMeasurement({
    List<CapturedPlantPartImage> capturedImages = const [],
    String measurementType = 'tree_height',
    double? referenceHeightM,
    double? subjectDistanceM,
    double? referenceDistanceM,
    double? subjectPixelSpan,
    double? referencePixelSpan,
  }) async {
    state = state.copyWith(isLoading: true, clearMessages: true);

    try {
      final measurement = await repository.measure(
        capturedImages: capturedImages,
        measurementType: measurementType,
        referenceHeightM: referenceHeightM,
        subjectDistanceM: subjectDistanceM,
        referenceDistanceM: referenceDistanceM,
        subjectPixelSpan: subjectPixelSpan,
        referencePixelSpan: referencePixelSpan,
      );

      state = MeasurementState(
        measurement: measurement,
        successMessage: 'Measurement estimate ready.',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to get measurement result. Please try again.',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  void clearMeasurement() {
    state = state.copyWith(clearMessages: true, clearMeasurement: true);
  }
}
