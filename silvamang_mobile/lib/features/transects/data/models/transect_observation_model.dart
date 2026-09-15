import '../../../map/data/models/map_scan_record.dart';
import '../../../../shared/models/scan_record_model.dart';

class TransectObservationModel {
  const TransectObservationModel({
    required this.reference,
    required this.recordCode,
    required this.scientificName,
    required this.commonName,
    this.serverId,
    this.offlineReference,
    this.heightM,
    this.canopyWidthM,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.locationName,
    this.notes,
    this.imagePath,
    this.capturedAt,
  });

  final String reference;
  final String? serverId;
  final String? offlineReference;
  final String recordCode;
  final String scientificName;
  final String commonName;
  final double? heightM;
  final double? canopyWidthM;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String? locationName;
  final String? notes;
  final String? imagePath;
  final DateTime? capturedAt;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isLocalOnly => serverId == null || serverId!.trim().isEmpty;

  factory TransectObservationModel.fromScanRecord(ScanRecordModel record) {
    final firstImage = record.images.isEmpty ? null : record.images.first;
    final imagePath = _firstText([
      firstImage?.imageUrl,
      firstImage?.localUri,
      firstImage?.imagePath,
    ]);
    final serverId = _nullableText(record.id);
    final offlineReference = _nullableText(record.offlineReference);

    return TransectObservationModel(
      reference: serverId ?? offlineReference ?? record.recordCode,
      serverId: serverId,
      offlineReference: offlineReference,
      recordCode: record.recordCode,
      scientificName: record.topScientificName,
      commonName: record.topCommonName,
      heightM: record.heightM ?? record.measurement?.heightM,
      canopyWidthM: record.canopyWidthM ?? record.measurement?.canopyWidthM,
      latitude: record.latitude ?? record.locationValidation?.latitude,
      longitude: record.longitude ?? record.locationValidation?.longitude,
      accuracyM: record.accuracy,
      locationName: _firstText([
        record.barangay,
        record.manualBarangay,
        record.locationName,
        record.address,
      ]),
      notes: _nullableText(record.notes),
      imagePath: imagePath,
      capturedAt: record.capturedAt ?? record.createdAt,
    );
  }

  factory TransectObservationModel.fromMapRecord(MapScanRecord record) {
    final serverId = _nullableText(record.serverId);

    return TransectObservationModel(
      reference: serverId ?? record.localId,
      serverId: serverId,
      offlineReference: serverId == null ? record.localId : null,
      recordCode: _nullableText(record.recordCode) ?? 'Local observation',
      scientificName: record.speciesName,
      commonName: record.commonName ?? '',
      heightM: record.heightM,
      canopyWidthM: record.canopyWidthM,
      latitude: record.latitude,
      longitude: record.longitude,
      accuracyM: record.accuracy,
      locationName: _firstText([
        record.barangay,
        record.manualBarangay,
        record.locationSource,
      ]),
      notes: record.notes,
      imagePath: record.imagePath,
      capturedAt: record.createdAt,
    );
  }

  factory TransectObservationModel.fromJson(Map<String, dynamic> json) {
    final serverId = _nullableText(json['id'] ?? json['server_id']);
    final offlineReference = _nullableText(
      json['offline_reference'] ?? json['offlineReference'],
    );
    final recordCode = _text(json['record_code'] ?? json['recordCode']);
    final reference =
        _nullableText(json['reference']) ??
        serverId ??
        offlineReference ??
        recordCode;

    return TransectObservationModel(
      reference: reference,
      serverId: serverId,
      offlineReference: offlineReference,
      recordCode: recordCode,
      scientificName: _text(
        json['scientific_name'] ??
            json['species_name'] ??
            json['top_scientific_name'],
      ),
      commonName: _text(json['common_name'] ?? json['top_common_name']),
      heightM: _asNullableDouble(json['height_m'] ?? json['heightM']),
      canopyWidthM: _asNullableDouble(
        json['canopy_width_m'] ?? json['canopyWidthM'],
      ),
      latitude: _asNullableDouble(json['latitude']),
      longitude: _asNullableDouble(json['longitude']),
      accuracyM: _asNullableDouble(json['accuracy_m'] ?? json['accuracy']),
      locationName: _nullableText(
        json['location_name'] ?? json['locationName'],
      ),
      notes: _nullableText(json['notes']),
      imagePath: _nullableText(
        json['image_url'] ?? json['image_path'] ?? json['imagePath'],
      ),
      capturedAt: _asDate(json['captured_at'] ?? json['capturedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reference': reference,
      'server_id': serverId,
      'offline_reference': offlineReference,
      'record_code': recordCode,
      'scientific_name': scientificName,
      'common_name': commonName,
      'height_m': heightM,
      'canopy_width_m': canopyWidthM,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'location_name': locationName,
      'notes': notes,
      'image_path': imagePath,
      'captured_at': capturedAt?.toIso8601String(),
    };
  }

  TransectObservationModel copyWith({
    String? reference,
    String? serverId,
    String? offlineReference,
    String? recordCode,
    String? scientificName,
    String? commonName,
    double? heightM,
    double? canopyWidthM,
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? locationName,
    String? notes,
    String? imagePath,
    DateTime? capturedAt,
  }) {
    return TransectObservationModel(
      reference: reference ?? this.reference,
      serverId: serverId ?? this.serverId,
      offlineReference: offlineReference ?? this.offlineReference,
      recordCode: recordCode ?? this.recordCode,
      scientificName: scientificName ?? this.scientificName,
      commonName: commonName ?? this.commonName,
      heightM: heightM ?? this.heightM,
      canopyWidthM: canopyWidthM ?? this.canopyWidthM,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyM: accuracyM ?? this.accuracyM,
      locationName: locationName ?? this.locationName,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _firstText(List<String?> values) {
    for (final value in values) {
      final text = _nullableText(value);
      if (text != null) {
        return text;
      }
    }
    return null;
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
    final text = value?.toString();
    return text == null || text.isEmpty ? null : DateTime.tryParse(text);
  }
}
