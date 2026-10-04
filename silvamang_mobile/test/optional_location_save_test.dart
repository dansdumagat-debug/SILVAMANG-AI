import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/core/services/api_client.dart';
import 'package:silvamang_mobile/features/capture/data/repositories/scan_image_repository.dart';
import 'package:silvamang_mobile/features/identification/data/models/mock_identification_result.dart';
import 'package:silvamang_mobile/features/records/data/repositories/scan_record_repository.dart';

class FakeApi extends Fake implements ApiClient {
  final calls = <String>[];
  Map<String, dynamic> scan = {};
  @override
  Future<Response<T>> post<T>(String path, {Object? data}) async {
    calls.add(path);
    if (path == '/scan-records') scan = Map<String, dynamic>.from(data! as Map);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          <String, dynamic>{
                'data': {...scan, 'id': '1'},
              }
              as T,
    );
  }

  @override
  Future<Response<T>> put<T>(String path, {Object? data}) async {
    calls.add(path);
    scan.addAll(Map<String, dynamic>.from(data! as Map));
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data:
          <String, dynamic>{
                'data': {...scan, 'id': '1'},
              }
              as T,
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: path),
    data:
        <String, dynamic>{
              'data': {...scan, 'id': '1'},
            }
            as T,
  );
}

class FakeImages extends Fake implements ScanImageRepository {}

void main() {
  test(
    'existing predicted record receives the save instant without another create',
    () async {
      final api = FakeApi();
      final repository = ScanRecordRepository(
        apiClient: api,
        scanImageRepository: FakeImages(),
      );
      await repository.updateObservationSavedAt(
        '1',
        DateTime.parse('2026-10-04T22:30:00+08:00'),
      );
      expect(api.calls, ['/scan-records/1']);
      expect(api.scan['captured_at'], '2026-10-04T14:30:00.000Z');
    },
  );

  for (final hasLocation in [false, true]) {
    test(
      'save with location=$hasLocation uses save instant and optional validation',
      () async {
        final api = FakeApi();
        final repository = ScanRecordRepository(
          apiClient: api,
          scanImageRepository: FakeImages(),
        );
        final result = MockIdentificationResult(
          scientificName: 'Rhizophora stylosa',
          commonName: '',
          confidence: double.nan,
          captureMode: 'manual_species',
          latitude: hasLocation ? 10.1 : null,
          longitude: hasLocation ? 124.8 : null,
          locationName: '',
          address: '',
          predictions: [],
          heightM: 9,
          canopyWidthM: double.nan,
          gbhCm: 174,
          canopy1M: 5,
          canopy2M: 3.5,
          measurementMethod: 'manual_input',
          measurementConfidence: double.nan,
          validationResult: 'not_checked',
          validationMessage: '',
          distanceToKnownDistributionKm: double.nan,
        );
        final savedAt = DateTime.parse('2026-10-04T22:30:00+08:00');
        await repository.createScanRecordFromMock(
          result: result,
          savedAt: savedAt,
          locationCapturedAt: DateTime.parse('2026-10-04T01:00:00Z'),
        );
        expect(api.scan['captured_at'], '2026-10-04T14:30:00.000Z');
        expect(api.scan['latitude'], hasLocation ? 10.1 : null);
        expect(
          api.calls.contains('/scan-records/1/validate-location'),
          hasLocation,
        );
      },
    );
  }
}
