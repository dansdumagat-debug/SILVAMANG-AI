import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:silvamang_mobile/core/routing/route_names.dart';
import 'package:silvamang_mobile/features/measurements/data/models/camera_measurement_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/shared/models/measurement_model.dart';
import 'package:silvamang_mobile/shared/widgets/structural_measurement_fields.dart';
import 'package:silvamang_mobile/features/offline_sync/data/models/offline_sync_item.dart';
import 'package:silvamang_mobile/features/identification/data/models/mock_identification_result.dart';

void main() {
  test(
    'girth conversion matches backend and survives offline JSON round trip',
    () {
      final result = MockIdentificationResult.sample.copyWith(
        gbhCm: 174,
        canopy1M: 4,
        canopy2M: 3.5,
      );
      expect(result.effectiveDbhCm, 55.39);
      expect(result.gbhM, 1.74);
      expect(result.dbhM, closeTo(.5539, .000001));
      final data = MeasurementModel.fromJson({
        'height_m': 5.2,
        'gbh_cm': result.gbhCm,
        'gbh_m': result.gbhM,
        'dbh_cm': result.effectiveDbhCm,
        'dbh_m': result.dbhM,
        'basal_area_m2': result.basalAreaM2,
        'canopy_1_m': result.canopy1M,
        'canopy_2_m': result.canopy2M,
        'canopy_width_m': null,
      });
      final restored = MeasurementModel.fromJson(
        jsonDecode(jsonEncode(data.toJson())),
      );
      expect(restored.gbhCm, 174);
      expect(restored.heightM, 5.2);
      expect(restored.canopy1M, 4);
      expect(restored.canopy2M, 3.5);
      expect(restored.toJson()['canopy_width_m'], isNull);
      expect(restored.basalAreaM2, closeTo(result.basalAreaM2!, .000001));
      final queued = OfflineSyncItem(
        id: 'structural-offline',
        type: OfflineSyncItem.typeScanRecordMockSave,
        payloadJson: jsonEncode({
          'scan_record': {'plot_no': '1'},
          'measurement': data.toJson(),
        }),
        status: OfflineSyncItem.statusPending,
        createdAt: DateTime(2026, 10, 2),
        ownerUserId: 'recorder-a',
      );
      final payload = jsonDecode(
        OfflineSyncItem.fromJson(queued.toJson()).payloadJson,
      );
      expect(payload['scan_record']['plot_no'], '1');
      expect(payload['measurement']['gbh_cm'], 174);
      expect(payload['measurement']['canopy_2_m'], 3.5);
      expect(payload['measurement']['canopy_width_m'], isNull);
    },
  );

  testWidgets(
    'manual structural inputs show conversions and validate invalid values',
    (tester) async {
      Map<String, double?> values = {};
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: key,
                child: StructuralMeasurementFields(
                  onChanged: (v) => values = v,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.textContaining('measured diameter (optional)'), findsNothing);
      expect(find.text('Measure Canopy 1 (m)'), findsOneWidget);
      expect(find.text('Measure Canopy 2 (m)'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '5');
      await tester.enterText(find.byType(TextFormField).at(2), '3.5');
      expect(values['canopy_1_m'], 5);
      expect(values['canopy_2_m'], 3.5);
      expect(values['dbh_cm'], isNull);
      await tester.enterText(find.byType(TextFormField).first, '174');
      await tester.pump();
      expect(values['gbh_cm'], 174);
      expect(find.textContaining('1.7400 m'), findsOneWidget);
      expect(find.textContaining('55.39 cm'), findsOneWidget);
      expect(key.currentState!.validate(), isTrue);
      await tester.enterText(find.byType(TextFormField).first, '-1');
      await tester.pump();
      expect(key.currentState!.validate(), isFalse);
      expect(values['gbh_cm'], isNull);
    },
  );
  testWidgets('camera axes save independently and request result-only mode', (
    tester,
  ) async {
    Map<String, double?> values = {};
    var capture = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              child: StructuralMeasurementFields(onChanged: (v) => values = v),
            ),
          ),
        ),
        GoRoute(
          path: '/camera',
          name: RouteNames.cameraPointingMeasurement,
          builder: (context, state) {
            expect(state.uri.queryParameters['result_only'], 'true');
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  capture++;
                  context.pop(
                    CameraMeasurementResult(
                      measurementType: 'canopy_width',
                      measurementMode: 'normal',
                      estimatedValueM: capture == 1 ? 5 : 3.5,
                      methodUsed: 'camera',
                      distanceSource: 'manual',
                      distanceM: 10,
                      arSupported: false,
                      arUsed: false,
                      reliability: 'accepted',
                      warningMessage: '',
                      createdAt: DateTime(2026),
                    ),
                  );
                },
                child: const Text('Use measurement'),
              ),
            );
          },
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    for (final axis in [1, 2]) {
      final button = find.text('Measure Canopy $axis (m)');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use measurement'));
      await tester.pumpAndSettle();
    }
    expect(values['canopy_1_m'], 5);
    expect(values['canopy_2_m'], 3.5);
    expect(values['canopy_width_m'], isNull);
    router.dispose();
  });
}
