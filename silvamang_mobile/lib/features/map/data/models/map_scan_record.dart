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
    this.recordCode,
    this.scannerName,
    this.isMine = true,
    this.canViewRecord = true,
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
    this.validationStatus,
  });

  final String localId;
  final String? serverId;
  final String? userId;
  final String? userEmail;
  final String? recordCode;
  final String? scannerName;
  final bool isMine;
  final bool canViewRecord;
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
  final String? validationStatus;
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

  bool belongsToOwner({
    String? ownerUserId,
    String? ownerUserEmail,
    bool includeOwnerless = false,
  }) {
    final recordEmail = _asNullableString(userEmail)?.toLowerCase();
    final requestedEmail = _asNullableString(ownerUserEmail)?.toLowerCase();
    if (recordEmail != null) {
      return requestedEmail != null && recordEmail == requestedEmail;
    }

    final recordId = _asNullableString(userId);
    final requestedId = _asNullableString(ownerUserId);
    if (recordId != null) {
      return requestedId != null && recordId == requestedId;
    }

    return includeOwnerless;
  }

  MapScanRecord copyWith({
    String? localId,
    String? serverId,
    String? userId,
    String? userEmail,
    String? recordCode,
    String? scannerName,
    bool? isMine,
    bool? canViewRecord,
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
    String? validationStatus,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MapScanRecord(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      recordCode: recordCode ?? this.recordCode,
      scannerName: scannerName ?? this.scannerName,
      isMine: isMine ?? this.isMine,
      canViewRecord: canViewRecord ?? this.canViewRecord,
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
      validationStatus: validationStatus ?? this.validationStatus,
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
      recordCode: _asNullableString(json['record_code'] ?? json['recordCode']),
      scannerName: _asNullableString(
        json['scanner_name'] ?? json['scannerName'],
      ),
      isMine: _asBool(json['is_mine'] ?? json['isMine'], fallback: true),
      canViewRecord: _asBool(
        json['can_view_record'] ?? json['canViewRecord'],
        fallback: true,
      ),
      speciesName: _asString(json['species_name'] ?? json['speciesName']),
      commonName: _asNullableString(json['common_name'] ?? json['commonName']),
      confidence: _asDouble(json['confidence']),
      imagePath: _asNullableString(
        json['image_path'] ?? json['imagePath'] ?? json['image_url'],
      ),
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
      validationStatus: _asNullableString(
        json['validation_status'] ?? json['validationStatus'],
      ),
      syncStatus: _asString(
        json['sync_status'] ?? json['syncStatus'],
        fallback: localOnly,
      ),
      createdAt: _asDateTime(
        json['created_at'] ?? json['createdAt'] ?? json['captured_at'],
      ),
      updatedAt: _asDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'server_id': serverId,
      'user_id': userId,
      'user_email': userEmail,
      'record_code': recordCode,
      'scanner_name': scannerName,
      'is_mine': isMine,
      'can_view_record': canViewRecord,
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
      'validation_status': validationStatus,
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

  static bool _asBool(Object? value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }

    return fallback;
  }

  static DateTime _asDateTime(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
