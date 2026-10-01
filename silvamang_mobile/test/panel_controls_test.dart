import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/core/widgets/record_pagination.dart';
import 'package:silvamang_mobile/core/widgets/silvamang_button.dart';

void main() {
  testWidgets('pagination disables boundaries and works on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var page = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RecordPagination(
              page: page,
              pages: 2,
              onChanged: (value) => setState(() => page = value),
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Previous'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Next'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Previous'));
    await tester.pump();
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long action labels wrap and loading prevents duplicate actions',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                child: SilvamangButton(
                  text: 'View all identification details',
                  icon: Icons.visibility,
                  type: SilvamangButtonType.secondary,
                  onPressed: () => calls++,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('View all identification details'));
      expect(calls, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SilvamangButton(
              text: 'Save',
              isLoading: true,
              onPressed: () => calls++,
            ),
          ),
        ),
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
