import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/ai_assistant/data/services/offline_mangrove_knowledge_service.dart';
import 'package:silvamang_mobile/shared/utils/species_taxonomy.dart';

void main() {
  test('legacy and misspelled species names use canonical display names', () {
    expect(
      canonicalSpeciesName('Avicennia_marina_var_rumphiana'),
      'Avicennia rumphiana',
    );
    expect(
      canonicalSpeciesName('Camptostemon phillipinensis'),
      'Camptostemon philippinensis',
    );
    expect(canonicalSpeciesName('Bruguiera sexangola'), 'Bruguiera sexangula');
    expect(
      canonicalSpeciesName('Scyphiphora hydrophyllacea'),
      'Scyphiphora hydrophylacea',
    );
    expect(
      canonicalSpeciesName('Xylocarpus moluccensis'),
      'Xylocarpus rumphii',
    );
  });

  test('species aliases normalize inside assistant questions', () {
    expect(
      normalizedSpeciesText('How do I identify Xylocarpus moluccensis?'),
      'how do i identify xylocarpus rumphii',
    );
  });

  testWidgets('offline assistant loads all twenty added species guides', (
    tester,
  ) async {
    const service = OfflineMangroveKnowledgeService();

    final acanthus = await service.answer(
      question: 'How can I identify Acanthus ebracteatus?',
    );
    expect(acanthus.relatedSpecies, contains('Acanthus ebracteatus'));
    expect(acanthus.response, contains('Leaf:'));

    final xylocarpus = await service.answer(
      question: 'How can I identify Xylocarpus moluccensis?',
    );
    expect(xylocarpus.relatedSpecies, contains('Xylocarpus rumphii'));
    expect(
      xylocarpus.response,
      contains('Related species: Xylocarpus rumphii'),
    );
  });
}
