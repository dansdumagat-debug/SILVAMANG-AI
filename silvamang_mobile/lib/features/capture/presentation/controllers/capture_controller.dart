import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/captured_plant_part_image.dart';

final captureControllerProvider =
    StateNotifierProvider<CaptureController, CaptureState>((ref) {
      return CaptureController(imagePicker: ImagePicker());
    });

class CaptureState {
  const CaptureState({
    this.capturedImages = const [],
    this.isPicking = false,
    this.errorMessage,
    this.successMessage,
  });

  final List<CapturedPlantPartImage> capturedImages;
  final bool isPicking;
  final String? errorMessage;
  final String? successMessage;

  int get capturedCount => capturedImages.length;
  bool get isReadyForIdentification => capturedImages.isNotEmpty;

  CaptureState copyWith({
    List<CapturedPlantPartImage>? capturedImages,
    bool? isPicking,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearMessages = false,
  }) {
    return CaptureState(
      capturedImages: capturedImages ?? this.capturedImages,
      isPicking: isPicking ?? this.isPicking,
      errorMessage: clearError || clearMessages
          ? null
          : errorMessage ?? this.errorMessage,
      successMessage: clearMessages
          ? null
          : successMessage ?? this.successMessage,
    );
  }

  bool hasImageFor(String plantPart) {
    return getImageFor(plantPart) != null;
  }

  CapturedPlantPartImage? getImageFor(String plantPart) {
    for (final image in capturedImages) {
      if (image.plantPart == plantPart) {
        return image;
      }
    }
    return null;
  }
}

class CaptureController extends StateNotifier<CaptureState> {
  CaptureController({required this.imagePicker}) : super(const CaptureState());

  final ImagePicker imagePicker;

  Future<void> pickFromCamera(String plantPart) {
    return _pickImage(plantPart: plantPart, source: ImageSource.camera);
  }

  Future<void> pickFromGallery(String plantPart) {
    return _pickImage(plantPart: plantPart, source: ImageSource.gallery);
  }

  void removeImage(String plantPart) {
    state = state.copyWith(
      capturedImages: [
        for (final image in state.capturedImages)
          if (image.plantPart != plantPart) image,
      ],
    );
  }

  void clearImages() {
    state = state.copyWith(capturedImages: const [], clearMessages: true);
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  Future<void> _pickImage({
    required String plantPart,
    required ImageSource source,
  }) async {
    state = state.copyWith(isPicking: true, clearMessages: true);
    try {
      final pickedFile = await imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile == null) {
        state = state.copyWith(isPicking: false);
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      final capturedImage = CapturedPlantPartImage(
        plantPart: plantPart,
        imagePath: pickedFile.path,
        fileName: pickedFile.name,
        previewBytes: bytes,
        capturedAt: DateTime.now(),
        source: source == ImageSource.camera ? 'camera' : 'gallery',
      );

      state = state.copyWith(
        isPicking: false,
        capturedImages: [
          for (final image in state.capturedImages)
            if (image.plantPart != plantPart) image,
          capturedImage,
        ],
        successMessage: 'Image selected for $plantPart.',
      );
    } catch (_) {
      state = state.copyWith(
        isPicking: false,
        errorMessage: 'Unable to select image. Please try again.',
      );
    }
  }
}
