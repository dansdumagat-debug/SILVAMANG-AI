import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../offline_sync/data/models/offline_sync_item.dart';
import '../../../offline_sync/data/repositories/offline_sync_repository.dart';
import '../models/map_scan_record.dart';

final localMapScanRepositoryProvider = Provider<LocalMapScanRepository>((ref) {
  return LocalMapScanRepository(
    offlineSyncRepository: ref.watch(offlineSyncRepositoryProvider),
  );
});

class LocalMapScanRepository {
  const LocalMapScanRepository({required this.offlineSyncRepository});

  static const itemType = 'map_scan_record';

  final OfflineSyncRepository offlineSyncRepository;

  Future<void> saveLocalRecord(MapScanRecord record) {
    return _upsertItem(
      OfflineSyncItem(
        id: _itemId(record.localId),
        type: itemType,
        payloadJson: jsonEncode(record.toJson()),
        status: _queueStatusFromMapStatus(record.syncStatus),
        createdAt: record.createdAt,
      ),
    );
  }

  Future<List<MapScanRecord>> getRecordsForUser({
    String? userId,
    String? userEmail,
    bool includeGuestRecords = false,
    bool includeLegacyRecords = false,
  }) async {
    final records = await _getAllMapRecords();
    final cleanUserId = _cleanText(userId);
    final cleanUserEmail = _cleanText(userEmail)?.toLowerCase();

    return records.where((record) {
      final recordUserId = _cleanText(record.userId);
      final recordUserEmail = _cleanText(record.userEmail)?.toLowerCase();

      if (cleanUserEmail != null && recordUserEmail == cleanUserEmail) {
        return true;
      }

      if (cleanUserId != null && recordUserId == cleanUserId) {
        return true;
      }

      if (recordUserEmail != null) {
        return false;
      }

      if (recordUserId != null) {
        return includeLegacyRecords &&
            (cleanUserEmail != null || cleanUserId != null);
      }

      return includeGuestRecords &&
          recordUserId == null &&
          recordUserEmail == null;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<MapScanRecord>> getPendingSyncRecords({
    String? userId,
    String? userEmail,
  }) async {
    final records = await getRecordsForUser(
      userId: userId,
      userEmail: userEmail,
      includeGuestRecords: userId == null && userEmail == null,
    );
    return records
        .where((record) => record.syncStatus == MapScanRecord.pending)
        .toList();
  }

  Future<void> updateSyncStatus({
    required String localId,
    required String syncStatus,
    String? serverId,
  }) async {
    final record = await _findByLocalId(localId);
    if (record == null) {
      return;
    }

    await saveLocalRecord(
      record.copyWith(
        serverId: serverId,
        syncStatus: syncStatus,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteLocalRecord(String localId) {
    return offlineSyncRepository.removeItem(_itemId(localId));
  }

  Future<List<MapScanRecord>> _getAllMapRecords() async {
    final items = [
      ...(await offlineSyncRepository.getRecentlyDeletedItems()),
      ...(await offlineSyncRepository.getItems()),
    ];
    final recordsByLocalId = <String, MapScanRecord>{};

    for (final item in items) {
      if (item.type != itemType) {
        continue;
      }

      try {
        final decoded = jsonDecode(item.payloadJson);
        if (decoded is Map<String, dynamic>) {
          final record = MapScanRecord.fromJson(decoded);
          recordsByLocalId[record.localId] = record;
        } else if (decoded is Map) {
          final record = MapScanRecord.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
          recordsByLocalId[record.localId] = record;
        }
      } catch (_) {
        // Skip malformed legacy map records so valid pins still render.
      }
    }

    return recordsByLocalId.values.toList();
  }

  Future<MapScanRecord?> _findByLocalId(String localId) async {
    final records = await _getAllMapRecords();
    for (final record in records) {
      if (record.localId == localId) {
        return record;
      }
    }
    return null;
  }

  Future<void> _upsertItem(OfflineSyncItem item) async {
    final items = await offlineSyncRepository.getItems();
    final exists = items.any((existing) => existing.id == item.id);
    if (exists) {
      await offlineSyncRepository.updateItem(item);
      return;
    }

    await offlineSyncRepository.addItem(item);
  }

  String _itemId(String localId) => '${itemType}_$localId';

  String? _cleanText(String? value) {
    final cleanValue = value?.trim();
    return cleanValue == null || cleanValue.isEmpty ? null : cleanValue;
  }

  String _queueStatusFromMapStatus(String syncStatus) {
    switch (syncStatus) {
      case MapScanRecord.synced:
        return OfflineSyncItem.statusSynced;
      case MapScanRecord.failed:
        return OfflineSyncItem.statusFailed;
      case MapScanRecord.pending:
      case MapScanRecord.localOnly:
      default:
        return OfflineSyncItem.statusPending;
    }
  }
}
