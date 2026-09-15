String canonicalSpeciesName(Object? value) {
  final displayName = value?.toString().replaceAll('_', ' ').trim() ?? '';
  final squished = displayName.replaceAll(RegExp(r'\s+'), ' ');
  final key = _rawSpeciesKey(squished);

  return _canonicalNames[key] ?? squished;
}

String normalizedSpeciesKey(Object? value) {
  return _rawSpeciesKey(canonicalSpeciesName(value));
}

String normalizedSpeciesText(Object? value) {
  var normalized = value
      .toString()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  final aliases = _canonicalNames.entries.toList()
    ..sort((left, right) => right.key.length.compareTo(left.key.length));

  for (final alias in aliases) {
    final aliasText = alias.key.replaceAll('_', ' ');
    final canonicalText = _rawSpeciesKey(alias.value).replaceAll('_', ' ');
    normalized = normalized.replaceAll(aliasText, canonicalText);
  }

  return normalized;
}

String _rawSpeciesKey(Object? value) {
  return value
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
}

const _canonicalNames = <String, String>{
  'acanthus_ebracteatus': 'Acanthus ebracteatus',
  'acanthus_ilicifolius': 'Acanthus ilicifolius',
  'acanthus_volubilis': 'Acanthus volubilis',
  'aegiceras_corniculatum': 'Aegiceras corniculatum',
  'aegiceras_floridum': 'Aegiceras floridum',
  'avicennia_alba': 'Avicennia alba',
  'avicennia_marina': 'Avicennia marina',
  'avicennia_marina_var_rumphiana': 'Avicennia rumphiana',
  'avicennia_officinalis': 'Avicennia officinalis',
  'avicennia_rumphiana': 'Avicennia rumphiana',
  'bruguiera_cylindrica': 'Bruguiera cylindrica',
  'bruguiera_gymnorhiza': 'Bruguiera gymnorrhiza',
  'bruguiera_gymnorrhiza': 'Bruguiera gymnorrhiza',
  'bruguiera_sexangola': 'Bruguiera sexangula',
  'bruguiera_sexangula': 'Bruguiera sexangula',
  'camptostemon_philippinense': 'Camptostemon philippinensis',
  'camptostemon_phillipinensis': 'Camptostemon philippinensis',
  'camptostemon_philippinensis': 'Camptostemon philippinensis',
  'ceriops_tagal': 'Ceriops tagal',
  'ceriops_zippeliana': 'Ceriops zippeliana',
  'excoecaria_agallocha': 'Excoecaria agallocha',
  'heritiera_littoralis': 'Heritiera littoralis',
  'lumnitzera_littorea': 'Lumnitzera littorea',
  'lumnitzera_racemosa': 'Lumnitzera racemosa',
  'nypa_fruticans': 'Nypa fruticans',
  'osbornia_octodonta': 'Osbornia octodonta',
  'pemphis_acidula': 'Pemphis acidula',
  'rhizophora_apiculata': 'Rhizophora apiculata',
  'rhizophora_mucronata': 'Rhizophora mucronata',
  'rhizophora_stylosa': 'Rhizophora stylosa',
  'scyphiphora_hydrophyllacea': 'Scyphiphora hydrophylacea',
  'scyphiphora_hydrophylacea': 'Scyphiphora hydrophylacea',
  'sonneratia_alba': 'Sonneratia alba',
  'sonneratia_ovata': 'Sonneratia ovata',
  'xylocarpus_granatum': 'Xylocarpus granatum',
  'xylocarpus_moluccensis': 'Xylocarpus rumphii',
  'xylocarpus_rumphii': 'Xylocarpus rumphii',
};
