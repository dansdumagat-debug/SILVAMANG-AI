import '../utils/species_taxonomy.dart';

class SpeciesModel {
  const SpeciesModel({
    required this.id,
    required this.scientificName,
    required this.commonName,
    required this.family,
    this.genus = '',
    this.description = '',
    required this.habitat,
    this.distributionNotes = '',
    this.ecologicalRole = '',
    this.identificationNotes = '',
    required this.conservationStatus,
    this.nativeStatus = '',
    this.maxHeightM,
    this.status = '',
    this.cnnSupported = false,
  });

  final int id;
  final String scientificName;
  final String commonName;
  final String family;
  final String genus;
  final String description;
  final String habitat;
  final String distributionNotes;
  final String ecologicalRole;
  final String identificationNotes;
  final String conservationStatus;
  final String nativeStatus;
  final double? maxHeightM;
  final String status;
  final bool cnnSupported;

  factory SpeciesModel.fromJson(Map<String, dynamic> json) {
    return SpeciesModel(
      id: _asInt(json['id']),
      scientificName: canonicalSpeciesName(
        json['scientific_name'] ?? json['scientificName'],
      ),
      commonName: _asString(json['common_name'] ?? json['commonName']),
      family: _asString(json['family']),
      genus: _asString(json['genus']),
      description: _asString(json['description']),
      habitat: _asString(json['habitat']),
      distributionNotes: _asString(
        json['distribution_notes'] ?? json['distributionNotes'],
      ),
      ecologicalRole: _asString(
        json['ecological_role'] ?? json['ecologicalRole'],
      ),
      identificationNotes: _asString(
        json['identification_notes'] ?? json['identificationNotes'],
      ),
      conservationStatus: _asString(
        json['conservation_status'] ?? json['conservationStatus'],
      ),
      nativeStatus: _asString(json['native_status'] ?? json['nativeStatus']),
      maxHeightM: _asDouble(json['max_height_m'] ?? json['maxHeightM']),
      status: _asString(json['status']),
      cnnSupported: _asBool(json['cnn_supported'] ?? json['cnnSupported']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scientific_name': scientificName,
      'common_name': commonName,
      'family': family,
      'genus': genus,
      'description': description,
      'habitat': habitat,
      'distribution_notes': distributionNotes,
      'ecological_role': ecologicalRole,
      'identification_notes': identificationNotes,
      'conservation_status': conservationStatus,
      'native_status': nativeStatus,
      'max_height_m': maxHeightM,
      'status': status,
      'cnn_supported': cnnSupported,
    };
  }

  static String _asString(Object? value) {
    return value?.toString() ?? '';
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }

    return const {'1', 'true', 'yes'}.contains(value?.toString().toLowerCase());
  }
}
