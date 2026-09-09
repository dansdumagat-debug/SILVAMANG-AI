class SpeciesEducationModel {
  const SpeciesEducationModel({
    required this.scientificName,
    required this.displayName,
    required this.commonName,
    required this.family,
    required this.distribution,
    required this.habitat,
    required this.description,
    required this.physicalCharacteristics,
    required this.leafCharacteristics,
    required this.rootCharacteristics,
    required this.ecologicalImportance,
    required this.history,
    required this.scientificStudy,
    required this.conservationInformation,
    required this.trivia,
    required this.locationValidationHint,
    required this.conservationNote,
    required this.references,
    this.imageAsset,
  });

  final String scientificName;
  final String displayName;
  final String commonName;
  final String family;
  final List<String> distribution;
  final List<String> habitat;
  final String description;
  final List<String> physicalCharacteristics;
  final String leafCharacteristics;
  final String rootCharacteristics;
  final List<String> ecologicalImportance;
  final String history;
  final String scientificStudy;
  final List<String> conservationInformation;
  final List<String> trivia;
  final String locationValidationHint;
  final String conservationNote;
  final List<String> references;
  final String? imageAsset;

  bool get isFallback => description == _fallbackDescription;
  bool get hasUsefulContent =>
      description.isNotEmpty ||
      habitat.isNotEmpty ||
      ecologicalImportance.isNotEmpty ||
      conservationInformation.isNotEmpty;

  factory SpeciesEducationModel.fromJson(Map<String, dynamic> json) {
    final conservation = _asStringList(json['conservation_information']);

    return SpeciesEducationModel(
      scientificName: _asString(json['scientific_name']),
      displayName: _asString(json['display_name']),
      commonName: _asString(json['common_name']),
      family: _asString(json['family']),
      distribution: _asStringList(json['distribution']),
      habitat: _asStringList(json['habitat']),
      description: _asString(json['overview'] ?? json['description']),
      physicalCharacteristics: _asStringList(json['physical_characteristics']),
      leafCharacteristics: _asString(json['leaf_characteristics']),
      rootCharacteristics: _asString(json['root_characteristics']),
      ecologicalImportance: _asStringList(json['ecological_importance']),
      history: _asString(json['history']),
      scientificStudy: _asString(json['scientific_study']),
      conservationInformation: conservation,
      trivia: _asStringList(json['interesting_facts'] ?? json['trivia']),
      locationValidationHint: _asString(json['location_validation_hint']),
      conservationNote:
          _asString(json['conservation_note']).isNotEmpty
              ? _asString(json['conservation_note'])
              : conservation.take(2).join(' '),
      references: _asStringList(json['references']),
      imageAsset: _asNullableString(json['image_asset']),
    );
  }

  factory SpeciesEducationModel.fallback(String scientificName) {
    final displayName = scientificName.trim().isEmpty
        ? 'Unknown species'
        : scientificName.trim().replaceAll('_', ' ');

    return SpeciesEducationModel(
      scientificName: scientificName,
      displayName: displayName,
      commonName: '',
      family: '',
      distribution: const [],
      habitat: const [],
      description: _fallbackDescription,
      physicalCharacteristics: const [],
      leafCharacteristics: '',
      rootCharacteristics: '',
      ecologicalImportance: const [
        'Mangroves protect shorelines by reducing wave energy and trapping sediment.',
        'Mangrove forests provide nursery habitat for young fish, crabs, shrimp, and other coastal organisms.',
        'Mangrove roots and soils store blue carbon that supports climate-change mitigation.',
      ],
      history:
          'Mangroves were known and used by coastal communities for centuries before formal scientific study documented their ecological value.',
      scientificStudy:
          'Scientific research on mangroves documents species taxonomy, root adaptations, salt tolerance, coastal protection, nursery habitat, and blue-carbon storage.',
      conservationInformation: const [
        'Avoid cutting, dumping waste, blocking tidal flow, and clearing mangrove areas.',
        'Use native species, suitable sites, and long-term monitoring when restoring mangroves.',
      ],
      trivia: const [],
      locationValidationHint: 'unknown',
      conservationNote:
          'Educational content should be reviewed by domain experts.',
      references: const [
        'Tomlinson, P. B. The Botany of Mangroves.',
        'Spalding, Kainuma, and Collins. World Atlas of Mangroves.',
        'FAO mangrove conservation and restoration guidance.',
      ],
    );
  }

  static String normalizedKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_]+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  static const _fallbackDescription =
      'Educational information is not available for this species yet.';
}

String _asString(Object? value) {
  return value?.toString().trim() ?? '';
}

String? _asNullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

List<String> _asStringList(Object? value) {
  if (value is String) {
    return value
        .split(RegExp(r'[\n;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  if (value is! List) {
    return const [];
  }

  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
