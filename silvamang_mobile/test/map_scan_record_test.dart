import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/map/data/models/map_scan_record.dart';

void main() {
  test('parses a community scan returned by the map API', () {
    final record = MapScanRecord.fromJson({
      'local_id': 'encrypted-record-id',
      'server_id': 'encrypted-record-id',
      'user_id': 'encrypted-user-id',
      'record_code': 'SC-OTHER-001',
      'scanner_name': 'Field User',
      'is_mine': false,
      'can_view_record': false,
      'species_name': 'Rhizophora apiculata',
      'image_url': 'https://example.test/storage/scan.jpg',
      'latitude': 10.31,
      'longitude': 125.01,
      'sync_status': 'synced',
      'captured_at': '2026-09-13T09:00:00+08:00',
      'updated_at': '2026-09-13T09:00:00+08:00',
    });

    expect(record.serverId, 'encrypted-record-id');
    expect(record.recordCode, 'SC-OTHER-001');
    expect(record.scannerName, 'Field User');
    expect(record.isMine, isFalse);
    expect(record.canViewRecord, isFalse);
    expect(record.imagePath, 'https://example.test/storage/scan.jpg');
    expect(record.hasCoordinates, isTrue);
  });

  test('matches only the local record owner', () {
    final record = MapScanRecord(
      localId: 'local-user-a',
      userId: 'encrypted-user-a',
      userEmail: 'user-a@example.test',
      speciesName: 'Rhizophora apiculata',
      syncStatus: MapScanRecord.pending,
      createdAt: DateTime(2026, 9, 13),
      updatedAt: DateTime(2026, 9, 13),
    );

    expect(
      record.belongsToOwner(
        ownerUserId: 'new-encrypted-value',
        ownerUserEmail: 'USER-A@example.test',
      ),
      isTrue,
    );
    expect(
      record.belongsToOwner(
        ownerUserId: 'encrypted-user-b',
        ownerUserEmail: 'user-b@example.test',
      ),
      isFalse,
    );
  });

  test(
    'does not expose ownerless local records unless explicitly requested',
    () {
      final record = MapScanRecord(
        localId: 'legacy-ownerless',
        speciesName: 'Avicennia marina',
        syncStatus: MapScanRecord.localOnly,
        createdAt: DateTime(2026, 9, 13),
        updatedAt: DateTime(2026, 9, 13),
      );

      expect(
        record.belongsToOwner(ownerUserEmail: 'user@example.test'),
        isFalse,
      );
      expect(
        record.belongsToOwner(
          ownerUserEmail: 'user@example.test',
          includeOwnerless: true,
        ),
        isTrue,
      );
    },
  );
}
