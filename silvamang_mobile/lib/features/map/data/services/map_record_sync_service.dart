import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../models/map_scan_record.dart';
import '../repositories/local_map_scan_repository.dart';

final mapRecordSyncServiceProvider = Provider<MapRecordSyncService>((ref) {
  final authState = ref.watch(authControllerProvider);
  return MapRecordSyncService(
    apiClient: ApiClient.instance,
    localMapScanRepository: ref.watch(localMapScanRepositoryProvider),
    userEmail: authState.user?.email,
  );
});

class MapRecordSyncResult {
  const MapRecordSyncResult({
    required this.syncedCount,
    required this.failedCount,
    required this.skippedCount,
  });

  final int syncedCount;
  final int failedCount;
  final int skippedCount;
}

class MapRecordSyncService {
  const MapRecordSyncService({
    required this.apiClient,
    required this.localMapScanRepository,
    required this.userEmail,
  });

  final ApiClient apiClient;
  final LocalMapScanRepository localMapScanRepository;
  final String? userEmail;

  Future<MapRecordSyncResult> syncPendingRecords() async {
    if (userEmail == null || userEmail!.trim().isEmpty) {
      return const MapRecordSyncResult(
        syncedCount: 0,
        failedCount: 0,
        skippedCount: 0,
      );
    }

    final pendingRecords = await localMapScanRepository.getPendingSyncRecords(
      userEmail: userEmail,
    );

    var syncedCount = 0;
    var failedCount = 0;
    var skippedCount = 0;

    for (final record in pendingRecords) {
      if (!record.hasCoordinates) {
        skippedCount++;
        continue;
      }

      try {
        final response = await apiClient.post<Map<String, dynamic>>(
          '/scan-records',
          data: _payloadFor(record),
        );
        final serverId = _extractServerId(response.data);
        await localMapScanRepository.updateSyncStatus(
          localId: record.localId,
          syncStatus: MapScanRecord.synced,
          serverId: serverId,
        );
        syncedCount++;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('SILVAMANG AI map record sync failed: $error');
        }
        await localMapScanRepository.updateSyncStatus(
          localId: record.localId,
          syncStatus: MapScanRecord.failed,
        );
        failedCount++;
      }
    }

    return MapRecordSyncResult(
      syncedCount: syncedCount,
      failedCount: failedCount,
      skippedCount: skippedCount,
    );
  }

  Map<String, dynamic> _payloadFor(MapScanRecord record) {
    return {
      'top_scientific_name': record.speciesName,
      'top_common_name': record.commonName,
      'confidence': record.confidence,
      'capture_mode': 'mobile_map_sync',
      'identification_status': 'completed',
      'validation_status': 'pending',
      'latitude': record.latitude,
      'longitude': record.longitude,
      'accuracy': record.accuracy,
      'barangay': record.barangay,
      'manual_barangay': record.manualBarangay,
      'location_lookup_status': record.locationLookupStatus,
      'height_m': record.heightM,
      'canopy_width_m': record.canopyWidthM,
      'location_name': _locationName(record),
      'address': _locationName(record),
      'notes': _notes(record),
      'captured_at': record.createdAt.toIso8601String(),
    };
  }

  String _locationName(MapScanRecord record) {
    final barangay = record.barangay?.trim();
    if (barangay != null && barangay.isNotEmpty) {
      return 'Barangay $barangay';
    }

    final manualBarangay = record.manualBarangay?.trim();
    if (manualBarangay != null && manualBarangay.isNotEmpty) {
      return 'Manual barangay note: $manualBarangay';
    }

    return record.hasCoordinates
        ? 'GPS captured location'
        : 'Location unavailable';
  }

  String _notes(MapScanRecord record) {
    return [
      'Synced from local map scan record.',
      if (record.barangay?.trim().isNotEmpty == true)
        'Barangay: ${record.barangay}.',
      if (record.manualBarangay?.trim().isNotEmpty == true)
        'Manual barangay note: ${record.manualBarangay}.',
      if (record.accuracy != null)
        'GPS accuracy: ${record.accuracy!.toStringAsFixed(1)} meters.',
      if (record.locationLookupStatus?.trim().isNotEmpty == true)
        'Barangay lookup: ${record.locationLookupStatus}.',
      if (record.fieldDistanceM != null)
        'Field distance: ${record.fieldDistanceM!.toStringAsFixed(2)} meters.',
      if (record.notes?.trim().isNotEmpty == true) record.notes!,
    ].join(' ');
  }

  String? _extractServerId(Map<String, dynamic>? responseData) {
    final data = responseData?['data'];
    if (data is Map) {
      return _asNullableString(data['id']);
    }
    return _asNullableString(responseData?['id']);
  }

  String? _asNullableString(Object? value) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? null : text;
  }
}
