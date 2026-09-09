class MapScanRecord {
  const MapScanRecord({
    required this.localId,
    required this.speciesName,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.serverId,
    this.userId,
    this.userEmail,
    this.commonName,
    this.confidence,
    this.imagePath,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.barangay,
    this.manualBarangay,
    this.locationLookupStatus,
    this.locationSource,
    this.heightM,
    this.canopyWidthM,
    this.fieldDistanceM,
    this.notes,
  });

  final String localId;
  final String? serverId;
  final String? userId;
  final String? userEmail;
  final String speciesName;
  final String? commonName;
  final double? confidence;
  final String? imagePath;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? barangay;
  final String? manualBarangay;
  final String? locationLookupStatus;
  final String? locationSource;
  final double? heightM;
  final double? canopyWidthM;
  final double? fieldDistanceM;
  final String? notes;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const synced = 'synced';
  static const pending = 'pending';
  static const failed = 'failed';
  static const localOnly = 'local_only';

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isSynced => syncStatus == synced;
  bool get isPending => syncStatus == pending;

  MapScanRecord copyWith({
    String? localId,
    String? serverId,
    String? userId,
    String? userEmail,
    String? speciesName,
    String? commonName,
    double? confidence,
    String? imagePath,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? barangay,
    String? manualBarangay,
    String? locationLookupStatus,
    String? locationSource,
    double? heightM,
    double? canopyWidthM,
    double? fieldDistanceM,
    String? notes,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MapScanRecord(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      speciesName: speciesName ?? this.speciesName,
      commonName: commonName ?? this.commonName,
      confidence: confidence ?? this.confidence,
      imagePath: imagePath ?? this.imagePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      barangay: barangay ?? this.barangay,
      manualBarangay: manualBarangay ?? this.manualBarangay,
      locationLookupStatus: locationLookupStatus ?? this.locationLookupStatus,
      locationSource: locationSource ?? this.locationSource,
      heightM: heightM ?? this.heightM,
      canopyWidthM: canopyWidthM ?? this.canopyWidthM,
      fieldDistanceM: fieldDistanceM ?? this.fieldDistanceM,
      notes: notes ?? this.notes,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MapScanRecord.fromJson(Map<String, dynamic> json) {
    return MapScanRecord(
      localId: _asString(json['local_id'] ?? json['localId']),
      serverId: _asNullableString(json['server_id'] ?? json['serverId']),
      userId: _asNullableString(json['user_id'] ?? json['userId']),
      userEmail: _asNullableString(json['user_email'] ?? json['userEmail']),
      speciesName: _asString(json['species_name'] ?? json['speciesName']),
      commonName: _asNullableString(json['common_name'] ?? json['commonName']),
      confidence: _asDouble(json['confidence']),
      imagePath: _asNullableString(json['image_path'] ?? json['imagePath']),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      accuracy: _asDouble(json['accuracy']),
      barangay: _asNullableString(json['barangay']),
      manualBarangay: _asNullableString(
        json['manual_barangay'] ?? json['manualBarangay'],
      ),
      locationLookupStatus: _asNullableString(
        json['location_lookup_status'] ?? json['locationLookupStatus'],
      ),
      locationSource: _asNullableString(
        json['location_source'] ?? json['locationSource'],
      ),
      heightM: _asDouble(json['height_m'] ?? json['heightM']),
      canopyWidthM: _asDouble(json['canopy_width_m'] ?? json['canopyWidthM']),
      fieldDistanceM: _asDouble(
        json['field_distance_m'] ?? json['fieldDistanceM'],
      ),
      notes: _asNullableString(json['notes']),
      syncStatus: _asString(
        json['sync_status'] ?? json['syncStatus'],
        fallback: localOnly,
      ),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'server_id': serverId,
      'user_id': userId,
      'user_email': userEmail,
      'species_name': speciesName,
      'common_name': commonName,
      'confidence': confidence,
      'image_path': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'barangay': barangay,
      'manual_barangay': manualBarangay,
      'location_lookup_status': locationLookupStatus,
      'location_source': locationSource,
      'height_m': heightM,
      'canopy_width_m': canopyWidthM,
      'field_distance_m': fieldDistanceM,
      'notes': notes,
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String _asString(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _asNullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime _asDateTime(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
