import 'transect_observation_model.dart';
import 'transect_point_model.dart';

class TransectRecordModel {
  const TransectRecordModel({
    required this.localId,
    required this.transectName,
    required this.mode,
    required this.status,
    required this.points,
    required this.observations,
    required this.totalDistanceM,
    required this.recordedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    this.serverId,
    this.ownerUserId,
    this.ownerUserEmail,
    this.researcherName,
    this.transectCode,
    this.locationName,
    this.description,
    this.bearingDegrees,
    this.gpsAccuracyM,
    this.pendingObservationReferences = const [],
    this.syncedAt,
    this.syncError,
  });

  static const modeGpsTracking = 'gps_tracking';
  static const modeManualPoints = 'manual_points';
  static const statusDraft = 'draft';
  static const statusCompleted = 'completed';
  static const syncPending = 'pending';
  static const syncSynced = 'synced';
  static const syncFailed = 'failed';

  final String localId;
  final String? serverId;
  final String? ownerUserId;
  final String? ownerUserEmail;
  final String? researcherName;
  final String? transectCode;
  final String transectName;
  final String? locationName;
  final String? description;
  final String mode;
  final String status;
  final List<TransectPointModel> points;
  final List<TransectObservationModel> observations;
  final double totalDistanceM;
  final double? bearingDegrees;
  final double? gpsAccuracyM;
  final List<String> pendingObservationReferences;
  final DateTime recordedAt;
  final DateTime? syncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String syncStatus;
  final String? syncError;

  TransectPointModel? get startPoint => points.isEmpty ? null : points.first;
  TransectPointModel? get endPoint => points.isEmpty ? null : points.last;
  bool get isGpsTracking => mode == modeGpsTracking;
  bool get isSynced => syncStatus == syncSynced;
  bool get hasPendingObservationLinks =>
      pendingObservationReferences.isNotEmpty;

  String get displayCode {
    final code = transectCode?.trim();
    return code == null || code.isEmpty ? 'LOCAL TRANSECT' : code;
  }

  String get directionLabel {
    final bearing = bearingDegrees;
    if (bearing == null) {
      return 'N/A';
    }
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return labels[(bearing / 45).round() % labels.length];
  }

  Map<String, int> get speciesDistribution {
    final counts = <String, int>{};
    for (final observation in observations) {
      final name = observation.scientificName.trim().isEmpty
          ? 'Unidentified'
          : observation.scientificName.trim();
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  bool belongsToOwner({String? userId, String? userEmail}) {
    final recordEmail = _nullableText(ownerUserEmail)?.toLowerCase();
    final requestedEmail = _nullableText(userEmail)?.toLowerCase();
    if (recordEmail != null && requestedEmail != null) {
      return recordEmail == requestedEmail;
    }

    final recordId = _nullableText(ownerUserId);
    final requestedId = _nullableText(userId);
    return recordId != null && requestedId != null && recordId == requestedId;
  }

  factory TransectRecordModel.fromJson(Map<String, dynamic> json) {
    final offlineReference = _nullableText(
      json['offline_reference'] ?? json['local_id'] ?? json['localId'],
    );
    final serverId = _nullableText(json['id'] ?? json['server_id']);
    final pendingReferences = _asStringList(
      json['pending_observation_references'],
    );
    final researcher = _asMap(json['researcher']);
    final recordedAt =
        _asDate(json['recorded_at'] ?? json['recordedAt']) ?? DateTime.now();

    return TransectRecordModel(
      localId:
          offlineReference ??
          'server_${serverId ?? recordedAt.microsecondsSinceEpoch}',
      serverId: serverId,
      ownerUserId: _nullableText(
        json['owner_user_id'] ?? json['user_id'] ?? researcher['id'],
      ),
      ownerUserEmail: _nullableText(
        json['owner_user_email'] ?? json['user_email'],
      ),
      researcherName: _nullableText(
        json['researcher_name'] ?? researcher['name'],
      ),
      transectCode: _nullableText(
        json['transect_code'] ?? json['transectCode'],
      ),
      transectName: _text(
        json['transect_name'] ?? json['transectName'],
        fallback: 'Unnamed Transect',
      ),
      locationName: _nullableText(
        json['location_name'] ?? json['locationName'],
      ),
      description: _nullableText(json['description']),
      mode: _text(json['mode'], fallback: modeManualPoints),
      status: _text(json['status'], fallback: statusCompleted),
      points: _asMaps(json['points']).map(TransectPointModel.fromJson).toList(),
      observations: _asMaps(
        json['observations'],
      ).map(TransectObservationModel.fromJson).toList(),
      totalDistanceM: _asDouble(
        json['total_distance_m'] ?? json['totalDistanceM'],
      ),
      bearingDegrees: _asNullableDouble(
        json['bearing_degrees'] ?? json['bearingDegrees'],
      ),
      gpsAccuracyM: _asNullableDouble(
        json['gps_accuracy_m'] ?? json['gpsAccuracyM'],
      ),
      pendingObservationReferences: pendingReferences,
      recordedAt: recordedAt,
      syncedAt: _asDate(json['synced_at'] ?? json['syncedAt']),
      createdAt: _asDate(json['created_at'] ?? json['createdAt']) ?? recordedAt,
      updatedAt: _asDate(json['updated_at'] ?? json['updatedAt']) ?? recordedAt,
      syncStatus: _text(
        json['sync_status'] ?? json['syncStatus'],
        fallback: serverId != null && pendingReferences.isEmpty
            ? syncSynced
            : syncPending,
      ),
      syncError: _nullableText(json['sync_error'] ?? json['syncError']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'server_id': serverId,
      'owner_user_id': ownerUserId,
      'owner_user_email': ownerUserEmail,
      'researcher_name': researcherName,
      'transect_code': transectCode,
      'transect_name': transectName,
      'location_name': locationName,
      'description': description,
      'mode': mode,
      'status': status,
      'points': points.map((point) => point.toJson()).toList(),
      'observations': observations
          .map((observation) => observation.toJson())
          .toList(),
      'total_distance_m': totalDistanceM,
      'bearing_degrees': bearingDegrees,
      'gps_accuracy_m': gpsAccuracyM,
      'pending_observation_references': pendingObservationReferences,
      'recorded_at': recordedAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
      'sync_error': syncError,
    };
  }

  Map<String, dynamic> toApiPayload() {
    final references = <String>{
      ...observations
          .map((observation) => observation.reference.trim())
          .where((reference) => reference.isNotEmpty),
      ...pendingObservationReferences
          .map((reference) => reference.trim())
          .where((reference) => reference.isNotEmpty),
    };

    return {
      'transect_name': transectName,
      'location_name': locationName,
      'description': description,
      'mode': mode,
      'status': status,
      'offline_reference': localId,
      'recorded_at': recordedAt.toIso8601String(),
      'points': points.map((point) => point.toJson()).toList(),
      'observation_references': references.toList(),
    };
  }

  TransectRecordModel copyWith({
    String? serverId,
    String? ownerUserId,
    String? ownerUserEmail,
    String? researcherName,
    String? transectCode,
    List<TransectObservationModel>? observations,
    double? totalDistanceM,
    double? bearingDegrees,
    double? gpsAccuracyM,
    List<String>? pendingObservationReferences,
    DateTime? syncedAt,
    DateTime? updatedAt,
    String? syncStatus,
    String? syncError,
    bool clearSyncError = false,
  }) {
    return TransectRecordModel(
      localId: localId,
      serverId: serverId ?? this.serverId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerUserEmail: ownerUserEmail ?? this.ownerUserEmail,
      researcherName: researcherName ?? this.researcherName,
      transectCode: transectCode ?? this.transectCode,
      transectName: transectName,
      locationName: locationName,
      description: description,
      mode: mode,
      status: status,
      points: points,
      observations: observations ?? this.observations,
      totalDistanceM: totalDistanceM ?? this.totalDistanceM,
      bearingDegrees: bearingDegrees ?? this.bearingDegrees,
      gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
      pendingObservationReferences:
          pendingObservationReferences ?? this.pendingObservationReferences,
      recordedAt: recordedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: clearSyncError ? null : syncError ?? this.syncError,
    );
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  static List<Map<String, dynamic>> _asMaps(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
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
    final text = value?.toString();
    return text == null || text.isEmpty ? null : DateTime.tryParse(text);
  }
}
