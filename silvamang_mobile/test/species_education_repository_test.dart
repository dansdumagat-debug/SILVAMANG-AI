import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/identification/data/repositories/species_education_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline guide resolves a predicted scientific name', () async {
    final education = await SpeciesEducationRepository.instance
        .findOfflineByScientificName('Avicennia_marina');

    expect(education.isFallback, isFalse);
    expect(education.commonName, 'Grey Mangrove');
    expect(education.habitat, isNotEmpty);
    expect(education.ecologicalImportance, isNotEmpty);
  });

  test(
    'Aegiceras floridum remains available as guide-only education',
    () async {
      final education = await SpeciesEducationRepository.instance
          .findOfflineByScientificName('Aegiceras_floridum');

      expect(education.isFallback, isFalse);
      expect(education.displayName, 'Aegiceras floridum');

      final guide =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/data/panel_mangrove_education.json',
                ),
              )
              as List<dynamic>;
      final entry = guide.cast<Map<String, dynamic>>().singleWhere(
        (item) => item['scientific_name'] == 'Aegiceras_floridum',
      );
      expect(entry['cnn_supported'], isFalse);

      final classOrder =
          (jsonDecode(
                    await rootBundle.loadString(
                      'assets/models/class_order.json',
                    ),
                  )
                  as List<dynamic>)
              .cast<String>();
      expect(classOrder, isNot(contains('Aegiceras_floridum')));
    },
  );
}
