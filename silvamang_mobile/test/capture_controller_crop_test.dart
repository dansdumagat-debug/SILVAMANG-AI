import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:silvamang_mobile/features/capture/presentation/controllers/capture_controller.dart';

void main() {
  test(
    'camera and gallery keep the cropped file and cancel keeps the old image',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'silvamang_crop_test_',
      );
      final cameraSource = File(
        '${directory.path}${Platform.pathSeparator}camera.jpg',
      );
      final cameraCrop = File(
        '${directory.path}${Platform.pathSeparator}camera_crop.jpg',
      );
      final gallerySource = File(
        '${directory.path}${Platform.pathSeparator}gallery.jpg',
      );
      final galleryCrop = File(
        '${directory.path}${Platform.pathSeparator}gallery_crop.jpg',
      );

      try {
        await cameraSource.writeAsBytes([1]);
        await cameraCrop.writeAsBytes([10, 11]);
        await gallerySource.writeAsBytes([2]);
        await galleryCrop.writeAsBytes([20, 21, 22]);

        final picker = _FakeImagePicker(
          camera: XFile(cameraSource.path),
          gallery: XFile(gallerySource.path),
        );
        final selectedForCropping = <String>[];
        var cancelCrop = false;
      final controller = _TestCaptureController(
          imagePicker: picker,
          cropImage: (sourcePath) async {
            selectedForCropping.add(sourcePath);
            if (cancelCrop) return null;
            return CroppedFile(
              sourcePath == cameraSource.path
                  ? cameraCrop.path
                  : galleryCrop.path,
            );
          },
        );

        await controller.pickFromCamera('leaves');
      final cameraImage = controller.currentState.getImageFor('leaves');
        expect(picker.lastSource, ImageSource.camera);
        expect(cameraImage?.imagePath, cameraCrop.path);
        expect(cameraImage?.fileName, 'camera_crop.jpg');
        expect(cameraImage?.previewBytes, [10, 11]);
        expect(cameraImage?.source, 'camera');

        await controller.pickFromGallery('leaves');
      final galleryImage = controller.currentState.getImageFor('leaves');
        expect(picker.lastSource, ImageSource.gallery);
        expect(galleryImage?.imagePath, galleryCrop.path);
        expect(galleryImage?.previewBytes, [20, 21, 22]);
        expect(galleryImage?.source, 'gallery');
        expect(selectedForCropping, [cameraSource.path, gallerySource.path]);

        cancelCrop = true;
        await controller.pickFromGallery('leaves');
      expect(controller.currentState.getImageFor('leaves'), same(galleryImage));
      expect(controller.currentState.isPicking, isFalse);
        controller.dispose();
      } finally {
        await cameraSource.delete();
        await cameraCrop.delete();
        await gallerySource.delete();
        await galleryCrop.delete();
        await directory.delete();
      }
    },
  );
}

class _FakeImagePicker extends ImagePicker {
  _FakeImagePicker({required this.camera, required this.gallery});

  final XFile camera;
  final XFile gallery;
  ImageSource? lastSource;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    lastSource = source;
    return source == ImageSource.camera ? camera : gallery;
  }
}

class _TestCaptureController extends CaptureController {
  _TestCaptureController({required super.imagePicker, required super.cropImage});

  CaptureState get currentState => state;
}
