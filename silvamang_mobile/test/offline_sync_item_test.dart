import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/features/offline_sync/data/models/offline_sync_item.dart';

void main() {
  OfflineSyncItem itemFor({String? userId, String? userEmail}) {
    return OfflineSyncItem(
      id: 'queue-item',
      type: OfflineSyncItem.typeScanRecordMockSave,
      payloadJson: '{}',
      status: OfflineSyncItem.statusPending,
      createdAt: DateTime(2026, 9, 13),
      ownerUserId: userId,
      ownerUserEmail: userEmail,
    );
  }

  test('offline scan belongs only to its account', () {
    final item = itemFor(
      userId: 'encrypted-user-a',
      userEmail: 'user-a@example.test',
    );

    expect(
      item.belongsToOwner(
        userId: 'new-encrypted-value',
        userEmail: 'USER-A@example.test',
      ),
      isTrue,
    );
    expect(
      item.belongsToOwner(
        userId: 'encrypted-user-b',
        userEmail: 'user-b@example.test',
      ),
      isFalse,
    );
  });

  test('owner metadata survives storage serialization', () {
    final original = itemFor(
      userId: 'encrypted-user-a',
      userEmail: 'user-a@example.test',
    );

    final restored = OfflineSyncItem.fromJson(original.toJson());

    expect(restored.ownerUserId, original.ownerUserId);
    expect(restored.ownerUserEmail, original.ownerUserEmail);
  });

  test('legacy ownerless queue item is hidden by default', () {
    final item = itemFor();

    expect(item.belongsToOwner(userEmail: 'user-a@example.test'), isFalse);
    expect(
      item.belongsToOwner(
        userEmail: 'user-a@example.test',
        includeOwnerless: true,
      ),
      isTrue,
    );
  });
}
