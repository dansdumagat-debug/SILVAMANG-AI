import 'package:flutter_riverpod/legacy.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/captured_plant_part_image.dart';

typedef CropPlantImage = Future<CroppedFile?> Function(String sourcePath);

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
  CaptureController({required this.imagePicker, CropPlantImage? cropImage})
    : _cropImage = cropImage ?? cropPlantImage,
      super(const CaptureState());

  final ImagePicker imagePicker;
  final CropPlantImage _cropImage;

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

      final croppedFile = await _cropImage(pickedFile.path);
      if (croppedFile == null) {
        state = state.copyWith(isPicking: false);
        return;
      }

      final bytes = await croppedFile.readAsBytes();
      final croppedPath = croppedFile.path;
      final capturedImage = CapturedPlantPartImage(
        plantPart: plantPart,
        imagePath: croppedPath,
        fileName: croppedPath.split(RegExp(r'[/\\]')).last,
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
        errorMessage: 'Unable to select or crop image. Please try again.',
      );
    }
  }
}

Future<CroppedFile?> cropPlantImage(String sourcePath) {
  return ImageCropper().cropImage(
    sourcePath: sourcePath,
    compressQuality: 90,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop mangrove photo',
        toolbarColor: AppColors.primaryDarkGreen,
        toolbarWidgetColor: AppColors.white,
        activeControlsWidgetColor: AppColors.primaryGreen,
        initAspectRatio: CropAspectRatioPreset.original,
        lockAspectRatio: false,
      ),
      IOSUiSettings(title: 'Crop mangrove photo'),
    ],
  );
}
