import 'dart:typed_data';

class CapturedPlantPartImage {
  const CapturedPlantPartImage({
    required this.plantPart,
    required this.imagePath,
    required this.fileName,
    required this.previewBytes,
    required this.capturedAt,
    required this.source,
  });

  final String plantPart;
  final String imagePath;
  final String fileName;
  final Uint8List previewBytes;
  final DateTime capturedAt;
  final String source;

  CapturedPlantPartImage copyWith({
    String? plantPart,
    String? imagePath,
    String? fileName,
    Uint8List? previewBytes,
    DateTime? capturedAt,
    String? source,
  }) {
    return CapturedPlantPartImage(
      plantPart: plantPart ?? this.plantPart,
      imagePath: imagePath ?? this.imagePath,
      fileName: fileName ?? this.fileName,
      previewBytes: previewBytes ?? this.previewBytes,
      capturedAt: capturedAt ?? this.capturedAt,
      source: source ?? this.source,
    );
  }
}
