import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/local_storage_service.dart';
import '../models/offline_sync_item.dart';

final offlineSyncRepositoryProvider = Provider<OfflineSyncRepository>((ref) {
  return OfflineSyncRepository(storage: LocalStorageService.instance);
});

class OfflineSyncRepository {
  const OfflineSyncRepository({required this.storage});

  static const _storageKey = 'offline_sync_queue';
  static const _recentlyDeletedStorageKey =
      'offline_sync_recently_deleted_queue';
  static const _maxRecentlyDeletedItems = 30;

  final LocalStorageService storage;

  Future<List<OfflineSyncItem>> getItems() async {
    return _readItems(_storageKey);
  }

  Future<List<OfflineSyncItem>> getRecentlyDeletedItems() async {
    final items = List<OfflineSyncItem>.of(
      await _readItems(_recentlyDeletedStorageKey),
    );
    return items..sort(_newestDeletedFirst);
  }

  Future<List<OfflineSyncItem>> getPendingItems() async {
    final items = await getItems();
    return items
        .where((item) => item.status == OfflineSyncItem.statusPending)
        .toList();
  }

  Future<List<OfflineSyncItem>> getFailedItems() async {
    final items = await getItems();
    return items
        .where((item) => item.status == OfflineSyncItem.statusFailed)
        .toList();
  }

  Future<void> addItem(OfflineSyncItem item) async {
    final items = await getItems();
    await _saveItems([...items, item]);
  }

  Future<void> updateItem(OfflineSyncItem item) async {
    final items = await getItems();
    await _saveItems([
      for (final existing in items)
        if (existing.id == item.id) item else existing,
    ]);
  }

  Future<void> removeItem(String id) async {
    final items = await getItems();
    final removedItems = items.where((item) => item.id == id).toList();
    await _archiveDeletedItems(removedItems);
    await _saveItems([
      for (final item in items)
        if (item.id != id) item,
    ]);
  }

  Future<void> clearSynced({String? onlyType}) async {
    final items = await getItems();
    final syncedItems = items
        .where(
          (item) =>
              item.status == OfflineSyncItem.statusSynced &&
              (onlyType == null || item.type == onlyType),
        )
        .toList();
    await _archiveDeletedItems(syncedItems);
    await _saveItems([
      for (final item in items)
        if (item.status != OfflineSyncItem.statusSynced ||
            (onlyType != null && item.type != onlyType))
          item,
    ]);
  }

  Future<void> restoreRecentlyDeletedItem(String id) async {
    final deletedItems = await getRecentlyDeletedItems();
    OfflineSyncItem? itemToRestore;
    final remainingDeletedItems = <OfflineSyncItem>[];

    for (final item in deletedItems) {
      if (item.id == id && itemToRestore == null) {
        itemToRestore = item;
      } else {
        remainingDeletedItems.add(item);
      }
    }

    if (itemToRestore == null) {
      return;
    }

    final activeItems = await getItems();
    final restoredItem = itemToRestore.copyWith(clearDeletedAt: true);
    var restored = false;
    final restoredItems = <OfflineSyncItem>[];
    for (final item in activeItems) {
      if (item.id == restoredItem.id) {
        restoredItems.add(restoredItem);
        restored = true;
      } else {
        restoredItems.add(item);
      }
    }

    if (!restored) {
      restoredItems.add(restoredItem);
    }

    await _saveItems(restoredItems);
    await _saveRecentlyDeletedItems(remainingDeletedItems);
  }

  Future<void> permanentlyDeleteRecentlyDeletedItem(String id) async {
    final deletedItems = await getRecentlyDeletedItems();
    await _saveRecentlyDeletedItems([
      for (final item in deletedItems)
        if (item.id != id) item,
    ]);
  }

  Future<void> clearRecentlyDeleted({String? onlyType}) async {
    if (onlyType == null) {
      await _saveRecentlyDeletedItems(const []);
      return;
    }

    final deletedItems = await getRecentlyDeletedItems();
    await _saveRecentlyDeletedItems([
      for (final item in deletedItems)
        if (item.type != onlyType) item,
    ]);
  }

  Future<int> pendingCount() async {
    final items = await getPendingItems();
    return items.length;
  }

  Future<int> failedCount() async {
    final items = await getFailedItems();
    return items.length;
  }

  Future<List<OfflineSyncItem>> _readItems(String storageKey) async {
    final raw = storage.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => OfflineSyncItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _archiveDeletedItems(List<OfflineSyncItem> items) async {
    if (items.isEmpty) {
      return;
    }

    final deletedAt = DateTime.now();
    final existingDeletedItems = await getRecentlyDeletedItems();
    final nextDeletedItems = <String, OfflineSyncItem>{
      for (final item in existingDeletedItems) item.id: item,
      for (final item in items) item.id: item.copyWith(deletedAt: deletedAt),
    }.values.toList()
      ..sort(_newestDeletedFirst);

    await _saveRecentlyDeletedItems(
      nextDeletedItems.take(_maxRecentlyDeletedItems).toList(),
    );
  }

  int _newestDeletedFirst(OfflineSyncItem a, OfflineSyncItem b) {
    return (b.deletedAt ?? b.createdAt).compareTo(a.deletedAt ?? a.createdAt);
  }

  Future<void> _saveItems(List<OfflineSyncItem> items) {
    return storage.saveString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveRecentlyDeletedItems(List<OfflineSyncItem> items) {
    return storage.saveString(
      _recentlyDeletedStorageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
