import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/transects/data/models/transect_observation_model.dart';
import 'package:silvamang_mobile/features/transects/data/models/transect_point_model.dart';
import 'package:silvamang_mobile/features/transects/data/models/transect_record_model.dart';

void main() {
  final recordedAt = DateTime.utc(2026, 9, 15, 8, 30);

  TransectRecordModel buildRecord() {
    return TransectRecordModel(
      localId: 'transect-local-1',
      ownerUserId: '42',
      ownerUserEmail: 'student@example.test',
      researcherName: 'Field Student',
      transectName: 'River Edge T1',
      locationName: 'Barangay Test',
      mode: TransectRecordModel.modeGpsTracking,
      status: TransectRecordModel.statusCompleted,
      points: [
        TransectPointModel(
          latitude: 14.5,
          longitude: 120.9,
          accuracyM: 4,
          recordedAt: recordedAt,
        ),
        TransectPointModel(
          latitude: 14.5005,
          longitude: 120.9005,
          accuracyM: 5,
          recordedAt: recordedAt.add(const Duration(minutes: 2)),
        ),
      ],
      observations: [
        TransectObservationModel(
          reference: 'scan-server-1',
          serverId: 'scan-server-1',
          recordCode: 'SCAN-001',
          scientificName: 'Avicennia marina',
          commonName: 'Bungalon',
          heightM: 3.2,
          latitude: 14.5,
          longitude: 120.9,
        ),
        const TransectObservationModel(
          reference: 'scan-local-2',
          offlineReference: 'scan-local-2',
          recordCode: 'LOCAL-002',
          scientificName: 'Avicennia marina',
          commonName: 'Bungalon',
        ),
      ],
      totalDistanceM: 77.5,
      bearingDegrees: 44,
      gpsAccuracyM: 4.5,
      pendingObservationReferences: const ['scan-local-2'],
      recordedAt: recordedAt,
      createdAt: recordedAt,
      updatedAt: recordedAt,
      syncStatus: TransectRecordModel.syncPending,
    );
  }

  test('round-trips local storage data without losing ownership', () {
    final original = buildRecord();
    final decoded = TransectRecordModel.fromJson(original.toJson());

    expect(decoded.localId, original.localId);
    expect(decoded.ownerUserId, '42');
    expect(decoded.ownerUserEmail, 'student@example.test');
    expect(decoded.points, hasLength(2));
    expect(decoded.observations, hasLength(2));
    expect(decoded.pendingObservationReferences, ['scan-local-2']);
    expect(decoded.speciesDistribution, {'Avicennia marina': 2});
    expect(decoded.belongsToOwner(userId: '42'), isTrue);
    expect(decoded.belongsToOwner(userId: '99'), isFalse);
  });

  test('creates an idempotent API payload with observation references', () {
    final payload = buildRecord().toApiPayload();

    expect(payload['offline_reference'], 'transect-local-1');
    expect(payload['mode'], TransectRecordModel.modeGpsTracking);
    expect(payload['points'], isA<List<dynamic>>());
    expect((payload['observation_references'] as List<dynamic>).toSet(), {
      'scan-server-1',
      'scan-local-2',
    });
  });

  test('uses server identity and sync state from an API response', () {
    final decoded = TransectRecordModel.fromJson({
      'id': 'encrypted-transect-id',
      'offline_reference': 'transect-local-1',
      'transect_name': 'River Edge T1',
      'mode': 'manual_points',
      'status': 'completed',
      'total_distance_m': 50,
      'recorded_at': recordedAt.toIso8601String(),
      'points': const [],
      'observations': const [],
      'pending_observation_references': const [],
    });

    expect(decoded.serverId, 'encrypted-transect-id');
    expect(decoded.localId, 'transect-local-1');
    expect(decoded.syncStatus, TransectRecordModel.syncSynced);
  });
}
