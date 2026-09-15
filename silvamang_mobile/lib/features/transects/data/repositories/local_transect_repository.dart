import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../offline_sync/data/models/offline_sync_item.dart';
import '../../../offline_sync/data/repositories/offline_sync_repository.dart';
import '../models/transect_record_model.dart';

final localTransectRepositoryProvider = Provider<LocalTransectRepository>((
  ref,
) {
  return LocalTransectRepository(
    offlineSyncRepository: ref.watch(offlineSyncRepositoryProvider),
  );
});

class LocalTransectRepository {
  const LocalTransectRepository({required this.offlineSyncRepository});

  final OfflineSyncRepository offlineSyncRepository;

  Future<void> save(TransectRecordModel transect) async {
    final item = OfflineSyncItem(
      id: _itemId(transect.localId),
      type: OfflineSyncItem.typeTransectRecord,
      payloadJson: jsonEncode(transect.toJson()),
      status: _queueStatus(transect.syncStatus),
      createdAt: transect.createdAt,
      ownerUserId: transect.ownerUserId,
      ownerUserEmail: transect.ownerUserEmail,
      syncedAt: transect.syncedAt,
      errorMessage: transect.syncError,
    );
    final items = await offlineSyncRepository.getItems();
    if (items.any((existing) => existing.id == item.id)) {
      await offlineSyncRepository.updateItem(item);
    } else {
      await offlineSyncRepository.addItem(item);
    }
  }

  Future<List<TransectRecordModel>> getForUser({
    required String? userId,
    required String? userEmail,
  }) async {
    final records = await _all();
    return records
        .where(
          (record) =>
              record.belongsToOwner(userId: userId, userEmail: userEmail),
        )
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  Future<TransectRecordModel?> findForUser({
    required String localId,
    required String? userId,
    required String? userEmail,
  }) async {
    final records = await getForUser(userId: userId, userEmail: userEmail);
    for (final record in records) {
      if (record.localId == localId || record.serverId == localId) {
        return record;
      }
    }
    return null;
  }

  Future<void> remove(String localId) {
    return offlineSyncRepository.removeItem(_itemId(localId));
  }

  Future<List<TransectRecordModel>> _all() async {
    final items = await offlineSyncRepository.getItems();
    final records = <String, TransectRecordModel>{};
    for (final item in items) {
      if (item.type != OfflineSyncItem.typeTransectRecord) {
        continue;
      }

      try {
        final decoded = jsonDecode(item.payloadJson);
        final map = decoded is Map<String, dynamic>
            ? decoded
            : decoded is Map
            ? decoded.map((key, value) => MapEntry(key.toString(), value))
            : null;
        if (map == null) {
          continue;
        }
        final parsed = TransectRecordModel.fromJson(map);
        records[parsed.localId] = parsed.copyWith(
          syncStatus: _transectStatus(item.status),
          syncError: item.errorMessage,
          clearSyncError: item.errorMessage == null,
        );
      } catch (_) {
        // Keep malformed legacy items out of field history without hiding valid data.
      }
    }
    return records.values.toList();
  }

  String _itemId(String localId) => 'transect_$localId';

  String _queueStatus(String status) {
    return switch (status) {
      TransectRecordModel.syncSynced => OfflineSyncItem.statusSynced,
      TransectRecordModel.syncFailed => OfflineSyncItem.statusFailed,
      _ => OfflineSyncItem.statusPending,
    };
  }

  String _transectStatus(String status) {
    return switch (status) {
      OfflineSyncItem.statusSynced => TransectRecordModel.syncSynced,
      OfflineSyncItem.statusFailed => TransectRecordModel.syncFailed,
      _ => TransectRecordModel.syncPending,
    };
  }
}
