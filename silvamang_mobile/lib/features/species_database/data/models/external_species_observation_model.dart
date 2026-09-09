class ExternalSpeciesReferenceResult {
  const ExternalSpeciesReferenceResult({
    required this.status,
    required this.message,
    required this.source,
    required this.speciesName,
    required this.cached,
    required this.observationCount,
    required this.photosCount,
    required this.observations,
    this.lastSyncedAt,
    this.importedCount = 0,
  });

  final String status;
  final String message;
  final String source;
  final String speciesName;
  final bool cached;
  final int observationCount;
  final int photosCount;
  final DateTime? lastSyncedAt;
  final int importedCount;
  final List<ExternalSpeciesObservationModel> observations;

  bool get hasObservations => observations.isNotEmpty;

  factory ExternalSpeciesReferenceResult.fromJson(Map<String, dynamic> json) {
    final payload = _asMap(json['data']).isNotEmpty ? _asMap(json['data']) : json;
    final observationsValue = payload['observations'];
    final observationsPayload = observationsValue is Map
        ? _asMap(observationsValue)['data']
        : observationsValue;
    final observations = _asList(observationsPayload)
        .map(ExternalSpeciesObservationModel.fromJson)
        .toList();

    return ExternalSpeciesReferenceResult(
      status: _asString(payload['status'], fallback: 'unknown'),
      message: _asString(json['message'] ?? payload['message']),
      source: _asString(payload['source'], fallback: 'inaturalist'),
      speciesName: _asString(payload['species_name'] ?? payload['speciesName']),
      cached: _asBool(payload['cached']),
      observationCount: _asInt(payload['observation_count'], observations.length),
      photosCount: _asInt(
        payload['photos_count'],
        observations.where((item) => item.photoUrl?.isNotEmpty == true).length,
      ),
      lastSyncedAt: _asDateTime(payload['last_synced_at']),
      importedCount: _asInt(payload['imported_count'], 0),
      observations: observations,
    );
  }

  factory ExternalSpeciesReferenceResult.unavailable(String speciesName) {
    return ExternalSpeciesReferenceResult(
      status: 'unavailable',
      message: 'External biodiversity references are unavailable offline.',
      source: 'inaturalist',
      speciesName: speciesName,
      cached: true,
      observationCount: 0,
      photosCount: 0,
      observations: const [],
    );
  }
}

class ExternalSpeciesObservationModel {
  const ExternalSpeciesObservationModel({
    required this.id,
    this.speciesId,
    required this.source,
    required this.sourceObservationId,
    this.sourceUrl,
    this.photoUrl,
    this.observer,
    this.location,
    this.latitude,
    this.longitude,
    this.observedDate,
    this.qualityGrade,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int? speciesId;
  final String source;
  final String sourceObservationId;
  final String? sourceUrl;
  final String? photoUrl;
  final String? observer;
  final String? location;
  final double? latitude;
  final double? longitude;
  final DateTime? observedDate;
  final String? qualityGrade;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory ExternalSpeciesObservationModel.fromJson(Map<String, dynamic> json) {
    return ExternalSpeciesObservationModel(
      id: _asInt(json['id'], 0),
      speciesId: _asNullableInt(json['species_id'] ?? json['speciesId']),
      source: _asString(json['source'], fallback: 'inaturalist'),
      sourceObservationId: _asString(
        json['source_observation_id'] ?? json['sourceObservationId'],
      ),
      sourceUrl: _asNullableString(json['source_url'] ?? json['sourceUrl']),
      photoUrl: _asNullableString(json['photo_url'] ?? json['photoUrl']),
      observer: _asNullableString(json['observer']),
      location: _asNullableString(json['location']),
      latitude: _asNullableDouble(json['latitude']),
      longitude: _asNullableDouble(json['longitude']),
      observedDate: _asDateTime(json['observed_date'] ?? json['observedDate']),
      qualityGrade: _asNullableString(
        json['quality_grade'] ?? json['qualityGrade'],
      ),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is! List) {
    return const [];
  }

  return value.map(_asMap).where((item) => item.isNotEmpty).toList();
}

String _asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _asInt(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

double? _asNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

bool _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1';
}

DateTime? _asDateTime(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}
