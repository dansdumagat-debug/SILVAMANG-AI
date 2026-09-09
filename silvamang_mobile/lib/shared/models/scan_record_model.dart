import 'location_validation_model.dart';
import 'measurement_model.dart';
import 'prediction_model.dart';
import 'scan_image_model.dart';

class ScanRecordModel {
  const ScanRecordModel({
    required this.id,
    required this.recordCode,
    this.userId,
    this.speciesId,
    required this.topScientificName,
    required this.topCommonName,
    required this.confidence,
    this.captureMode = '',
    this.identificationStatus = '',
    required this.validationStatus,
    this.latitude,
    this.longitude,
    this.accuracy,
    required this.locationName,
    this.address = '',
    this.barangay,
    this.manualBarangay,
    this.locationLookupStatus,
    this.heightM,
    this.canopyWidthM,
    this.notes = '',
    this.offlineReference = '',
    this.capturedAt,
    this.syncedAt,
    required this.createdAt,
    this.updatedAt,
    this.images = const [],
    this.predictions = const [],
    this.measurement,
    this.locationValidation,
  });

  final String id;
  final String recordCode;
  final String? userId;
  final int? speciesId;
  final String topScientificName;
  final String topCommonName;
  final double confidence;
  final String captureMode;
  final String identificationStatus;
  final String validationStatus;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String locationName;
  final String address;
  final String? barangay;
  final String? manualBarangay;
  final String? locationLookupStatus;
  final double? heightM;
  final double? canopyWidthM;
  final String notes;
  final String offlineReference;
  final DateTime? capturedAt;
  final DateTime? syncedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ScanImageModel> images;
  final List<PredictionModel> predictions;
  final MeasurementModel? measurement;
  final LocationValidationModel? locationValidation;

  factory ScanRecordModel.fromJson(Map<String, dynamic> json) {
    return ScanRecordModel(
      id: _asString(json['id']),
      recordCode: _asString(json['record_code'] ?? json['recordCode']),
      userId: _asNullableString(json['user_id'] ?? json['userId']),
      speciesId: _asNullableInt(json['species_id'] ?? json['speciesId']),
      topScientificName: _asString(
        json['top_scientific_name'] ?? json['topScientificName'],
      ),
      topCommonName: _asString(
        json['top_common_name'] ?? json['topCommonName'],
      ),
      confidence: _asDouble(json['confidence']),
      captureMode: _asString(json['capture_mode'] ?? json['captureMode']),
      identificationStatus: _asString(
        json['identification_status'] ?? json['identificationStatus'],
      ),
      validationStatus: _asString(
        json['validation_status'] ?? json['validationStatus'],
      ),
      latitude: _asNullableDouble(json['latitude']),
      longitude: _asNullableDouble(json['longitude']),
      accuracy: _asNullableDouble(json['accuracy']),
      locationName: _asString(json['location_name'] ?? json['locationName']),
      address: _asString(json['address']),
      barangay: _asNullableString(json['barangay']),
      manualBarangay: _asNullableString(
        json['manual_barangay'] ?? json['manualBarangay'],
      ),
      locationLookupStatus: _asNullableString(
        json['location_lookup_status'] ?? json['locationLookupStatus'],
      ),
      heightM: _asNullableDouble(json['height_m'] ?? json['heightM']),
      canopyWidthM: _asNullableDouble(
        json['canopy_width_m'] ?? json['canopyWidthM'],
      ),
      notes: _asString(json['notes']),
      offlineReference: _asString(
        json['offline_reference'] ?? json['offlineReference'],
      ),
      capturedAt: _asDate(json['captured_at'] ?? json['capturedAt']),
      syncedAt: _asDate(json['synced_at'] ?? json['syncedAt']),
      createdAt:
          _asDate(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      updatedAt: _asDate(json['updated_at'] ?? json['updatedAt']),
      images: _asImages(json['images']),
      predictions: _asPredictions(json['predictions']),
      measurement: _asMeasurement(json['measurement']),
      locationValidation: _asLocationValidation(
        json['location_validation'] ?? json['locationValidation'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'record_code': recordCode,
      'user_id': userId,
      'species_id': speciesId,
      'top_scientific_name': topScientificName,
      'top_common_name': topCommonName,
      'confidence': confidence,
      'capture_mode': captureMode,
      'identification_status': identificationStatus,
      'validation_status': validationStatus,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_name': locationName,
      'address': address,
      'barangay': barangay,
      'manual_barangay': manualBarangay,
      'location_lookup_status': locationLookupStatus,
      'height_m': heightM,
      'canopy_width_m': canopyWidthM,
      'notes': notes,
      'offline_reference': offlineReference,
      'captured_at': capturedAt?.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'images': images.map((image) => image.toJson()).toList(),
      'predictions': predictions
          .map((prediction) => prediction.toJson())
          .toList(),
      'measurement': measurement?.toJson(),
      'location_validation': locationValidation?.toJson(),
    };
  }

  static List<PredictionModel> _asPredictions(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(PredictionModel.fromJson)
        .toList();
  }

  static List<ScanImageModel> _asImages(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, dynamic>>()
        .map(ScanImageModel.fromJson)
        .toList();
  }

  static MeasurementModel? _asMeasurement(Object? value) {
    if (value is Map<String, dynamic>) {
      return MeasurementModel.fromJson(value);
    }
    return null;
  }

  static LocationValidationModel? _asLocationValidation(Object? value) {
    if (value is Map<String, dynamic>) {
      return LocationValidationModel.fromJson(value);
    }
    return null;
  }

  static String _asString(Object? value) {
    return value?.toString() ?? '';
  }

  static String? _asNullableString(Object? value) {
    final text = value?.toString();

    return text == null || text.isEmpty ? null : text;
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

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asNullableDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static DateTime? _asDate(Object? value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}
