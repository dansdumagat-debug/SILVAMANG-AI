import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/connectivity_service.dart';
import '../models/transect_observation_model.dart';
import '../models/transect_record_model.dart';
import 'local_transect_repository.dart';
import 'transect_api_repository.dart';

final transectRepositoryProvider = Provider<TransectRepository>((ref) {
  return TransectRepository(
    localRepository: ref.watch(localTransectRepositoryProvider),
    apiRepository: ref.watch(transectApiRepositoryProvider),
    connectivityService: const ConnectivityService(),
  );
});

class TransectLoadResult {
  const TransectLoadResult({
    required this.records,
    required this.isOnline,
    this.warningMessage,
  });

  final List<TransectRecordModel> records;
  final bool isOnline;
  final String? warningMessage;
}

class TransectSyncResult {
  const TransectSyncResult({
    required this.records,
    required this.syncedCount,
    required this.failedCount,
  });

  final List<TransectRecordModel> records;
  final int syncedCount;
  final int failedCount;
}

class TransectSaveResult {
  const TransectSaveResult({required this.record, required this.synced});

  final TransectRecordModel record;
  final bool synced;
}

class TransectRepository {
  const TransectRepository({
    required this.localRepository,
    required this.apiRepository,
    required this.connectivityService,
  });

  final LocalTransectRepository localRepository;
  final TransectApiRepository apiRepository;
  final ConnectivityService connectivityService;

  Future<TransectLoadResult> load({
    required String? userId,
    required String? userEmail,
    required bool authenticated,
  }) async {
    var localRecords = await localRepository.getForUser(
      userId: userId,
      userEmail: userEmail,
    );
    final hasNetwork = await connectivityService.hasNetworkConnection();
    if (!hasNetwork || !authenticated) {
      return TransectLoadResult(records: localRecords, isOnline: false);
    }

    try {
      final remoteRecords = await apiRepository.getMine();
      final merged = _mergeCollections(
        localRecords: localRecords,
        remoteRecords: remoteRecords,
        userId: userId,
        userEmail: userEmail,
      );
      for (final record in merged) {
        await localRepository.save(record);
      }
      localRecords = await localRepository.getForUser(
        userId: userId,
        userEmail: userEmail,
      );
      return TransectLoadResult(records: localRecords, isOnline: true);
    } catch (error) {
      return TransectLoadResult(
        records: localRecords,
        isOnline: false,
        warningMessage:
            'Cloud transects are unavailable. Showing saved field records. $error',
      );
    }
  }

  Future<TransectSaveResult> saveNew(
    TransectRecordModel transect, {
    required bool authenticated,
  }) async {
    await localRepository.save(transect);
    if (!authenticated || !await connectivityService.hasNetworkConnection()) {
      return TransectSaveResult(record: transect, synced: false);
    }

    try {
      final synced = await _syncOne(transect);
      return TransectSaveResult(
        record: synced,
        synced: synced.syncStatus == TransectRecordModel.syncSynced,
      );
    } catch (error) {
      final failed = transect.copyWith(
        syncStatus: TransectRecordModel.syncFailed,
        syncError: error.toString(),
        updatedAt: DateTime.now(),
      );
      await localRepository.save(failed);
      return TransectSaveResult(record: failed, synced: false);
    }
  }

  Future<TransectSyncResult> syncPending({
    required String? userId,
    required String? userEmail,
    required bool authenticated,
  }) async {
    var records = await localRepository.getForUser(
      userId: userId,
      userEmail: userEmail,
    );
    if (!authenticated || !await connectivityService.hasNetworkConnection()) {
      return TransectSyncResult(
        records: records,
        syncedCount: 0,
        failedCount: 0,
      );
    }

    var syncedCount = 0;
    var failedCount = 0;
    for (final record in records.where(_needsSync).toList()) {
      try {
        final synced = await _syncOne(record);
        if (synced.syncStatus == TransectRecordModel.syncSynced) {
          syncedCount++;
        }
      } catch (error) {
        final failed = record.copyWith(
          syncStatus: TransectRecordModel.syncFailed,
          syncError: error.toString(),
          updatedAt: DateTime.now(),
        );
        await localRepository.save(failed);
        failedCount++;
      }
    }

    records = await localRepository.getForUser(
      userId: userId,
      userEmail: userEmail,
    );
    return TransectSyncResult(
      records: records,
      syncedCount: syncedCount,
      failedCount: failedCount,
    );
  }

  Future<void> delete(
    TransectRecordModel transect, {
    required bool authenticated,
  }) async {
    final serverId = transect.serverId;
    if (authenticated &&
        serverId != null &&
        await connectivityService.hasNetworkConnection()) {
      await apiRepository.delete(serverId);
    }
    await localRepository.remove(transect.localId);
  }

  Future<TransectRecordModel> _syncOne(TransectRecordModel local) async {
    final remote = await apiRepository.save(local);
    final mergedObservations = _mergeObservations(
      local.observations,
      remote.observations,
    );
    final hasPendingLinks = remote.pendingObservationReferences.isNotEmpty;
    final synced = remote.copyWith(
      ownerUserId: local.ownerUserId ?? remote.ownerUserId,
      ownerUserEmail: local.ownerUserEmail,
      researcherName: local.researcherName ?? remote.researcherName,
      observations: mergedObservations,
      syncStatus: hasPendingLinks
          ? TransectRecordModel.syncPending
          : TransectRecordModel.syncSynced,
      syncedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      clearSyncError: true,
    );
    final localIdentity = TransectRecordModel(
      localId: local.localId,
      serverId: synced.serverId,
      ownerUserId: synced.ownerUserId,
      ownerUserEmail: synced.ownerUserEmail,
      researcherName: synced.researcherName,
      transectCode: synced.transectCode,
      transectName: synced.transectName,
      locationName: synced.locationName,
      description: synced.description,
      mode: synced.mode,
      status: synced.status,
      points: synced.points,
      observations: synced.observations,
      totalDistanceM: synced.totalDistanceM,
      bearingDegrees: synced.bearingDegrees,
      gpsAccuracyM: synced.gpsAccuracyM,
      pendingObservationReferences: synced.pendingObservationReferences,
      recordedAt: synced.recordedAt,
      syncedAt: synced.syncedAt,
      createdAt: local.createdAt,
      updatedAt: synced.updatedAt,
      syncStatus: synced.syncStatus,
    );
    await localRepository.save(localIdentity);
    return localIdentity;
  }

  List<TransectRecordModel> _mergeCollections({
    required List<TransectRecordModel> localRecords,
    required List<TransectRecordModel> remoteRecords,
    required String? userId,
    required String? userEmail,
  }) {
    final records = <String, TransectRecordModel>{
      for (final local in localRecords) local.localId: local,
    };

    for (final remote in remoteRecords) {
      final key = remote.localId;
      final local = records[key];
      final hasPendingLinks = remote.pendingObservationReferences.isNotEmpty;
      final normalized = remote.copyWith(
        ownerUserId: userId ?? remote.ownerUserId,
        ownerUserEmail: userEmail,
        observations: local == null
            ? remote.observations
            : _mergeObservations(local.observations, remote.observations),
        syncStatus: hasPendingLinks
            ? TransectRecordModel.syncPending
            : TransectRecordModel.syncSynced,
        clearSyncError: true,
      );
      records[key] = normalized;
    }

    return records.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  List<TransectObservationModel> _mergeObservations(
    List<TransectObservationModel> local,
    List<TransectObservationModel> remote,
  ) {
    final observations = <String, TransectObservationModel>{};
    for (final observation in local) {
      observations[_observationKey(observation)] = observation;
    }
    for (final observation in remote) {
      final key = _observationKey(observation);
      final previous = observations[key];
      observations[key] = previous == null
          ? observation
          : observation.copyWith(
              imagePath: observation.imagePath ?? previous.imagePath,
              notes: observation.notes ?? previous.notes,
              offlineReference:
                  observation.offlineReference ?? previous.offlineReference,
            );
    }
    return observations.values.toList();
  }

  String _observationKey(TransectObservationModel observation) {
    final code = observation.recordCode.trim();
    if (code.isNotEmpty && code != 'Local observation') {
      return 'code:$code';
    }
    final offlineReference = observation.offlineReference?.trim();
    if (offlineReference != null && offlineReference.isNotEmpty) {
      return 'offline:$offlineReference';
    }
    return 'reference:${observation.reference}';
  }

  bool _needsSync(TransectRecordModel record) {
    return record.syncStatus != TransectRecordModel.syncSynced ||
        record.hasPendingObservationLinks;
  }
}
