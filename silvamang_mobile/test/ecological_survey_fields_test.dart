import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/shared/widgets/ecological_survey_fields.dart';

void main() {
  testWidgets('survey fields retain selections and validate census count', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    Map<String, dynamic> result = {};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: EcologicalSurveyFields(
              initial: const {
                'survey_location': 'Inside',
                'ecological_category': 'Sapling',
                'count_mg': 41,
              },
              onChanged: (v) => result = v,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Inside'), findsOneWidget);
    expect(find.text('Sapling'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '0');
    expect(key.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(TextFormField), '56');
    expect(key.currentState!.validate(), isTrue);
    expect(result, {
      'survey_location': 'Inside',
      'ecological_category': 'Sapling',
      'count_mg': 56,
    });
    await tester.enterText(find.byType(TextFormField), '');
    expect(key.currentState!.validate(), isTrue);
    expect(result['count_mg'], isNull);
  });
}
