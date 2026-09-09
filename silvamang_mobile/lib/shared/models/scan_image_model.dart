class ScanImageModel {
  const ScanImageModel({
    required this.id,
    required this.scanRecordId,
    required this.plantPart,
    required this.imagePath,
    required this.imageUrl,
    required this.originalFilename,
    required this.mimeType,
    required this.fileSize,
    this.width,
    this.height,
    this.localUri,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String scanRecordId;
  final String plantPart;
  final String imagePath;
  final String imageUrl;
  final String originalFilename;
  final String mimeType;
  final int fileSize;
  final int? width;
  final int? height;
  final String? localUri;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ScanImageModel.fromJson(Map<String, dynamic> json) {
    return ScanImageModel(
      id: _asString(json['id']),
      scanRecordId: _asString(json['scan_record_id'] ?? json['scanRecordId']),
      plantPart: _asString(json['plant_part'] ?? json['plantPart']),
      imagePath: _asString(json['image_path'] ?? json['imagePath']),
      imageUrl: _asString(json['image_url'] ?? json['imageUrl']),
      originalFilename: _asString(
        json['original_filename'] ?? json['originalFilename'],
      ),
      mimeType: _asString(json['mime_type'] ?? json['mimeType']),
      fileSize: _asInt(json['file_size'] ?? json['fileSize']),
      width: _asNullableInt(json['width']),
      height: _asNullableInt(json['height']),
      localUri: _asNullableString(json['local_uri'] ?? json['localUri']),
      createdAt: _asDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scan_record_id': scanRecordId,
      'plant_part': plantPart,
      'image_path': imagePath,
      'image_url': imageUrl,
      'original_filename': originalFilename,
      'mime_type': mimeType,
      'file_size': fileSize,
      'width': width,
      'height': height,
      'local_uri': localUri,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static String _asString(Object? value) {
    return value?.toString() ?? '';
  }

  static String? _asNullableString(Object? value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }
    return value.toString();
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static DateTime? _asDate(Object? value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
