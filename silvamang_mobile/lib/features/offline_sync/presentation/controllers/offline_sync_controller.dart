import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../records/data/repositories/scan_record_repository.dart';
import '../../data/models/offline_sync_item.dart';
import '../../data/repositories/offline_sync_repository.dart';

final offlineSyncControllerProvider =
    StateNotifierProvider<OfflineSyncController, OfflineSyncState>((ref) {
      return OfflineSyncController(
        connectivityService: const ConnectivityService(),
        offlineSyncRepository: ref.watch(offlineSyncRepositoryProvider),
        scanRecordRepository: ref.watch(scanRecordRepositoryProvider),
      );
    });

class OfflineSyncState {
  const OfflineSyncState({
    this.items = const [],
    this.recentlyDeletedItems = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.isOnline = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.syncedCount = 0,
    this.recentlyDeletedCount = 0,
    this.errorMessage,
    this.successMessage,
  });

  final List<OfflineSyncItem> items;
  final List<OfflineSyncItem> recentlyDeletedItems;
  final bool isLoading;
  final bool isSyncing;
  final bool isOnline;
  final int pendingCount;
  final int failedCount;
  final int syncedCount;
  final int recentlyDeletedCount;
  final String? errorMessage;
  final String? successMessage;

  OfflineSyncState copyWith({
    List<OfflineSyncItem>? items,
    List<OfflineSyncItem>? recentlyDeletedItems,
    bool? isLoading,
    bool? isSyncing,
    bool? isOnline,
    int? pendingCount,
    int? failedCount,
    int? syncedCount,
    int? recentlyDeletedCount,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    final nextItems = items ?? this.items;
    final nextRecentlyDeletedItems =
        recentlyDeletedItems ?? this.recentlyDeletedItems;
    return OfflineSyncState(
      items: nextItems,
      recentlyDeletedItems: nextRecentlyDeletedItems,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      pendingCount:
          pendingCount ?? _count(nextItems, OfflineSyncItem.statusPending),
      failedCount:
          failedCount ?? _count(nextItems, OfflineSyncItem.statusFailed),
      syncedCount:
          syncedCount ?? _count(nextItems, OfflineSyncItem.statusSynced),
      recentlyDeletedCount:
          recentlyDeletedCount ?? nextRecentlyDeletedItems.length,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      successMessage: clearMessages
          ? null
          : successMessage ?? this.successMessage,
    );
  }

  static int _count(List<OfflineSyncItem> items, String status) {
    return items.where((item) => item.status == status).length;
  }
}

class OfflineSyncController extends StateNotifier<OfflineSyncState> {
  OfflineSyncController({
    required this.connectivityService,
    required this.offlineSyncRepository,
    required this.scanRecordRepository,
  }) : super(const OfflineSyncState());

  final ConnectivityService connectivityService;
  final OfflineSyncRepository offlineSyncRepository;
  final ScanRecordRepository scanRecordRepository;
  static const _syncQueueType = OfflineSyncItem.typeScanRecordMockSave;

  Future<void> loadQueue() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    final isOnline = await connectivityService.isOnline();
    final items = (await offlineSyncRepository.getItems())
        .where(_isSyncQueueItem)
        .toList();
    final recentlyDeletedItems =
        (await offlineSyncRepository.getRecentlyDeletedItems())
            .where(_isSyncQueueItem)
            .toList();
    state = state.copyWith(
      items: items,
      recentlyDeletedItems: recentlyDeletedItems,
      isOnline: isOnline,
      isLoading: false,
    );
  }

  Future<void> refreshConnectivity() async {
    final isOnline = await connectivityService.isOnline();
    state = state.copyWith(isOnline: isOnline);
  }

  Future<void> addPendingScanSave(Map<String, dynamic> payload) async {
    final now = DateTime.now();
    final item = OfflineSyncItem(
      id: 'scan_${now.microsecondsSinceEpoch}',
      type: OfflineSyncItem.typeScanRecordMockSave,
      payloadJson: jsonEncode(payload),
      status: OfflineSyncItem.statusPending,
      createdAt: now,
    );

    await offlineSyncRepository.addItem(item);
    await loadQueue();
  }

  Future<void> syncPendingItems() async {
    if (state.isSyncing) {
      return;
    }

    await refreshConnectivity();
    if (!state.isOnline) {
      state = state.copyWith(
        errorMessage:
            'You are offline. Connect to the internet before syncing.',
      );
      return;
    }

    state = state.copyWith(isSyncing: true, clearMessages: true);
    final pendingItems = (await offlineSyncRepository.getPendingItems())
        .where(_isSyncQueueItem)
        .toList();
    var syncedCount = 0;

    for (final item in pendingItems) {
      final synced = await _syncItem(item);
      if (synced) {
        syncedCount += 1;
      }
    }

    final items = (await offlineSyncRepository.getItems())
        .where(_isSyncQueueItem)
        .toList();
    state = state.copyWith(
      items: items,
      isSyncing: false,
      successMessage: syncedCount == 0
          ? 'No pending items were synced.'
          : '$syncedCount pending item(s) synced.',
    );
  }

  Future<void> retryItem(String id) async {
    if (state.isSyncing) {
      return;
    }

    await refreshConnectivity();
    if (!state.isOnline) {
      state = state.copyWith(
        errorMessage:
            'You are offline. Connect to the internet before retrying.',
      );
      return;
    }

    final item = await _findItem(id);
    if (item == null) {
      state = state.copyWith(errorMessage: 'Queued item was not found.');
      return;
    }

    state = state.copyWith(isSyncing: true, clearMessages: true);
    final synced = await _syncItem(item);
    final items = (await offlineSyncRepository.getItems())
        .where(_isSyncQueueItem)
        .toList();
    state = state.copyWith(
      items: items,
      isSyncing: false,
      successMessage: synced ? 'Queued item synced successfully.' : null,
      errorMessage: synced
          ? null
          : 'Queued item failed to sync. See item error.',
    );
  }

  Future<void> clearSynced() async {
    await offlineSyncRepository.clearSynced(onlyType: _syncQueueType);
    await loadQueue();
    state = state.copyWith(
      successMessage:
          'Synced item(s) moved to Recently Deleted. You can restore them if needed.',
    );
  }

  Future<void> removeItem(String id) async {
    await offlineSyncRepository.removeItem(id);
    await loadQueue();
    state = state.copyWith(
      successMessage:
          'Item moved to Recently Deleted. Restore it there if this was accidental.',
    );
  }

  Future<void> restoreRecentlyDeletedItem(String id) async {
    await offlineSyncRepository.restoreRecentlyDeletedItem(id);
    await loadQueue();
    state = state.copyWith(successMessage: 'Deleted item restored.');
  }

  Future<void> permanentlyDeleteRecentlyDeletedItem(String id) async {
    await offlineSyncRepository.permanentlyDeleteRecentlyDeletedItem(id);
    await loadQueue();
    state = state.copyWith(successMessage: 'Recently deleted item removed.');
  }

  Future<void> clearRecentlyDeleted() async {
    await offlineSyncRepository.clearRecentlyDeleted(onlyType: _syncQueueType);
    await loadQueue();
    state = state.copyWith(successMessage: 'Recently Deleted cleared.');
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  bool _isSyncQueueItem(OfflineSyncItem item) {
    return item.type == _syncQueueType;
  }

  Future<OfflineSyncItem?> _findItem(String id) async {
    final items = await offlineSyncRepository.getItems();
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<bool> _syncItem(OfflineSyncItem item) async {
    final attemptAt = DateTime.now();
    final syncingItem = item.copyWith(
      status: OfflineSyncItem.statusSyncing,
      lastAttemptAt: attemptAt,
      clearError: true,
      clearSyncedAt: true,
    );
    await offlineSyncRepository.updateItem(syncingItem);

    try {
      if (item.type != OfflineSyncItem.typeScanRecordMockSave) {
        throw const FormatException('Unsupported offline sync item type.');
      }

      final decoded = jsonDecode(item.payloadJson);
      if (decoded is! Map) {
        throw const FormatException('Invalid offline sync payload.');
      }

      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (!_hasRequiredScanPayload(payload)) {
        throw const FormatException(
          'This queued item does not contain enough data for automatic sync.',
        );
      }

      await scanRecordRepository.createScanRecordFromOfflinePayload(payload);
      await offlineSyncRepository.updateItem(
        syncingItem.copyWith(
          status: OfflineSyncItem.statusSynced,
          lastAttemptAt: attemptAt,
          syncedAt: DateTime.now(),
          clearError: true,
        ),
      );
      return true;
    } catch (error) {
      await offlineSyncRepository.updateItem(
        syncingItem.copyWith(
          status: OfflineSyncItem.statusFailed,
          lastAttemptAt: attemptAt,
          retryCount: item.retryCount + 1,
          errorMessage: _readableError(error),
        ),
      );
      return false;
    }
  }

  bool _hasRequiredScanPayload(Map<String, dynamic> payload) {
    final scan = payload['scan_record'];
    if (scan is! Map) {
      return false;
    }

    return scan['top_scientific_name'] != null &&
        scan['top_common_name'] != null &&
        scan['confidence'] != null &&
        scan['captured_at'] != null;
  }

  String _readableError(Object error) {
    final message = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatException: ', '');
    return message.isEmpty
        ? 'Unable to sync this queued item. Please try again.'
        : message;
  }
}
