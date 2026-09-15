import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../offline_sync/presentation/controllers/offline_sync_controller.dart';
import '../../data/models/transect_record_model.dart';
import '../../data/repositories/local_transect_repository.dart';
import '../../data/repositories/transect_repository.dart';

final transectsControllerProvider =
    StateNotifierProvider<TransectsController, TransectsState>((ref) {
      final authState = ref.watch(authControllerProvider);
      final controller = TransectsController(
        repository: ref.watch(transectRepositoryProvider),
        localRepository: ref.watch(localTransectRepositoryProvider),
        connectivityService: const ConnectivityService(),
        currentUserId: authState.user?.id,
        currentUserEmail: authState.user?.email,
        researcherName: authState.user?.name,
        authenticated: authState.isAuthenticated,
        syncObservationQueue: () async {
          final notifier = ref.read(offlineSyncControllerProvider.notifier);
          await notifier.loadQueue();
          if (ref.read(offlineSyncControllerProvider).pendingCount > 0) {
            await notifier.syncPendingItems();
          }
        },
      );
      return controller;
    });

class TransectsState {
  const TransectsState({
    this.records = const [],
    this.selectedRecord,
    this.isLoading = false,
    this.isSaving = false,
    this.isSyncing = false,
    this.isOnline = false,
    this.errorMessage,
    this.successMessage,
  });

  final List<TransectRecordModel> records;
  final TransectRecordModel? selectedRecord;
  final bool isLoading;
  final bool isSaving;
  final bool isSyncing;
  final bool isOnline;
  final String? errorMessage;
  final String? successMessage;

  int get pendingCount => records
      .where((record) => record.syncStatus != TransectRecordModel.syncSynced)
      .length;
  double get totalDistanceM =>
      records.fold(0, (total, record) => total + record.totalDistanceM);
  int get observationCount =>
      records.fold(0, (total, record) => total + record.observations.length);

  TransectsState copyWith({
    List<TransectRecordModel>? records,
    TransectRecordModel? selectedRecord,
    bool? isLoading,
    bool? isSaving,
    bool? isSyncing,
    bool? isOnline,
    String? errorMessage,
    String? successMessage,
    bool clearSelectedRecord = false,
    bool clearMessages = false,
  }) {
    return TransectsState(
      records: records ?? this.records,
      selectedRecord: clearSelectedRecord
          ? null
          : selectedRecord ?? this.selectedRecord,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      successMessage: clearMessages
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}

class TransectsController extends StateNotifier<TransectsState> {
  TransectsController({
    required this.repository,
    required this.localRepository,
    required this.connectivityService,
    required this.currentUserId,
    required this.currentUserEmail,
    required this.researcherName,
    required this.authenticated,
    required this.syncObservationQueue,
  }) : super(const TransectsState()) {
    _connectivitySubscription = connectivityService.watchOnlineStatus().listen((
      isOnline,
    ) {
      state = state.copyWith(isOnline: isOnline);
      if (isOnline) {
        unawaited(syncPending(automatic: true));
      }
    });
  }

  final TransectRepository repository;
  final LocalTransectRepository localRepository;
  final ConnectivityService connectivityService;
  final String? currentUserId;
  final String? currentUserEmail;
  final String? researcherName;
  final bool authenticated;
  final Future<void> Function() syncObservationQueue;
  StreamSubscription<bool>? _connectivitySubscription;

  Future<void> load() async {
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final localRecords = await localRepository.getForUser(
        userId: currentUserId,
        userEmail: currentUserEmail,
      );
      state = state.copyWith(records: localRecords);

      final result = await repository.load(
        userId: currentUserId,
        userEmail: currentUserEmail,
        authenticated: authenticated,
      );
      state = state.copyWith(
        records: result.records,
        isLoading: false,
        isOnline: result.isOnline,
        errorMessage: result.warningMessage,
      );
      if (result.isOnline && state.pendingCount > 0) {
        await syncPending(automatic: true);
      }
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Transect history could not be loaded: $error',
      );
    }
  }

  Future<TransectRecordModel?> save(TransectRecordModel transect) async {
    if (state.isSaving) {
      return null;
    }
    state = state.copyWith(isSaving: true, clearMessages: true);
    try {
      final result = await repository.saveNew(
        transect,
        authenticated: authenticated,
      );
      final records = await localRepository.getForUser(
        userId: currentUserId,
        userEmail: currentUserEmail,
      );
      state = state.copyWith(
        records: records,
        selectedRecord: result.record,
        isSaving: false,
        isOnline: result.synced || state.isOnline,
        successMessage: result.synced
            ? 'Transect saved and synchronized.'
            : 'Transect saved on this device. It will sync when the server is available.',
      );
      return result.record;
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Transect could not be saved: $error',
      );
      return null;
    }
  }

  Future<void> syncPending({bool automatic = false}) async {
    if (state.isSyncing || !authenticated) {
      return;
    }
    state = state.copyWith(isSyncing: true, clearMessages: !automatic);
    try {
      await syncObservationQueue();
      final result = await repository.syncPending(
        userId: currentUserId,
        userEmail: currentUserEmail,
        authenticated: authenticated,
      );
      state = state.copyWith(
        records: result.records,
        isSyncing: false,
        isOnline: true,
        successMessage: automatic || result.syncedCount == 0
            ? null
            : '${result.syncedCount} transect(s) synchronized.',
        errorMessage: result.failedCount == 0
            ? null
            : '${result.failedCount} transect(s) still need synchronization.',
      );
    } catch (error) {
      state = state.copyWith(
        isSyncing: false,
        isOnline: false,
        errorMessage: automatic ? state.errorMessage : 'Sync failed: $error',
      );
    }
  }

  Future<void> select(String id) async {
    for (final record in state.records) {
      if (record.localId == id || record.serverId == id) {
        state = state.copyWith(selectedRecord: record, clearMessages: true);
        return;
      }
    }

    final record = await localRepository.findForUser(
      localId: id,
      userId: currentUserId,
      userEmail: currentUserEmail,
    );
    state = state.copyWith(
      selectedRecord: record,
      errorMessage: record == null ? 'Transect record was not found.' : null,
      clearMessages: record != null,
    );
  }

  Future<bool> delete(TransectRecordModel transect) async {
    try {
      await repository.delete(transect, authenticated: authenticated);
      final records = await localRepository.getForUser(
        userId: currentUserId,
        userEmail: currentUserEmail,
      );
      state = state.copyWith(
        records: records,
        clearSelectedRecord: true,
        successMessage: 'Transect removed.',
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Transect could not be removed: $error',
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearMessages: true);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
