import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/transects/data/models/transect_contribution_model.dart';
import 'package:silvamang_mobile/features/transects/data/models/transect_point_model.dart';
import 'package:silvamang_mobile/features/transects/data/models/transect_record_model.dart';
import 'package:silvamang_mobile/features/transects/data/services/transect_handoff_codec.dart';

void main() {
  test('QR frames preserve multiple users and reject mixed handoffs', () {
    final now = DateTime.utc(2026, 9, 16);
    final points = List.generate(
      80,
      (i) => TransectPointModel(
        latitude: 14.5 + i / 100000,
        longitude: 120.9 + i / 100000,
        recordedAt: now.add(Duration(seconds: i)),
      ),
    );
    final contributions = [
      TransectContributionModel(
        id: 'one',
        userId: 'u1',
        userName: 'One',
        distanceM: 15,
        points: points.take(40).toList(),
        observations: const [],
        recordedAt: now,
      ),
      TransectContributionModel(
        id: 'two',
        userId: 'u2',
        userName: 'Two',
        distanceM: 32,
        points: points.skip(40).toList(),
        observations: const [],
        recordedAt: now,
      ),
    ];
    final record = TransectRecordModel(
      localId: 'transect-1',
      transectName: 'Test',
      mode: TransectRecordModel.modeGpsTracking,
      status: TransectRecordModel.statusDraft,
      points: points,
      observations: const [],
      totalDistanceM: 47,
      targetDistanceM: 100,
      contributions: contributions,
      handoffSequence: 2,
      recordedAt: now,
      createdAt: now,
      updatedAt: now,
      syncStatus: TransectRecordModel.syncPending,
    );
    final qr = TransectHandoffCodec.encode(record);
    expect(qr.length, greaterThan(1));
    final restored = TransectHandoffCodec.decode(
      qr.map(TransectHandoffCodec.parse).toList().reversed.toList(),
    );
    expect(restored.totalDistanceM, 47);
    expect(restored.remainingDistanceM, 53);
    expect(restored.contributions.map((item) => item.userName), ['One', 'Two']);
    expect(restored.points, hasLength(80));
    expect(
      () => TransectHandoffCodec.decode(
        qr.skip(1).map(TransectHandoffCodec.parse).toList(),
      ),
      throwsFormatException,
    );
  });
}
