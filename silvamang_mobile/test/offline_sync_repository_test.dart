import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/core/services/local_storage_service.dart';
import 'package:silvamang_mobile/features/offline_sync/data/models/offline_sync_item.dart';
import 'package:silvamang_mobile/features/offline_sync/data/repositories/offline_sync_repository.dart';

class MemoryQueueStorage extends Fake implements LocalStorageService {
  final values = <String, String>{};
  bool failNextWrite = false;
  @override
  String? getString(String key) => values[key];
  @override
  Future<void> saveString(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Disk write failed');
    }
    values[key] = value;
  }
}

OfflineSyncItem queued(String id) => OfflineSyncItem(
  id: id,
  type: OfflineSyncItem.typeScanRecordMockSave,
  payloadJson: '{}',
  status: OfflineSyncItem.statusPending,
  createdAt: DateTime(2026, 10, 9),
);

void main() {
  test('simultaneous scan saves retain every queued record', () async {
    final storage = MemoryQueueStorage();
    final a = OfflineSyncRepository(storage: storage);
    final b = OfflineSyncRepository(storage: storage);
    await Future.wait(
      List.generate(20, (i) => (i.isEven ? a : b).addItem(queued('$i'))),
    );
    expect((await a.getItems()).map((e) => e.id).toSet(), {
      for (var i = 0; i < 20; i++) '$i',
    });
  });
  test('sync status update cannot overwrite a newly captured scan', () async {
    final repository = OfflineSyncRepository(storage: MemoryQueueStorage());
    final first = queued('first');
    await repository.addItem(first);
    await Future.wait([
      repository.updateItem(
        first.copyWith(status: OfflineSyncItem.statusSynced),
      ),
      repository.addItem(queued('new')),
    ]);
    final items = await repository.getItems();
    expect(items.length, 2);
    expect(
      items.firstWhere((e) => e.id == 'first').status,
      OfflineSyncItem.statusSynced,
    );
  });
  test('deleting and restoring history preserve concurrent captures', () async {
    final repository = OfflineSyncRepository(storage: MemoryQueueStorage());
    await repository.addItem(queued('old'));
    await Future.wait([
      repository.removeItem('old'),
      repository.addItem(queued('new')),
    ]);
    expect((await repository.getItems()).single.id, 'new');
    expect((await repository.getRecentlyDeletedItems()).single.id, 'old');
    await Future.wait([
      repository.restoreRecentlyDeletedItem('old'),
      repository.addItem(queued('newer')),
    ]);
    expect((await repository.getItems()).map((item) => item.id).toSet(), {
      'old',
      'new',
      'newer',
    });
    expect(await repository.getRecentlyDeletedItems(), isEmpty);
  });

  test('failed writes are reported and do not block later saves', () async {
    final storage = MemoryQueueStorage()..failNextWrite = true;
    final repository = OfflineSyncRepository(storage: storage);
    await expectLater(repository.addItem(queued('failed')), throwsStateError);
    await repository.addItem(queued('next'));
    expect((await repository.getItems()).single.id, 'next');
  });
}
