import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../models/map_scan_record.dart';

final mapScanRepositoryProvider = Provider<MapScanRepository>((ref) {
  return MapScanRepository(apiClient: ApiClient.instance);
});

class MapScanFeed {
  const MapScanFeed({
    required this.records,
    required this.myScans,
    required this.myPins,
    required this.allScans,
    required this.allPins,
  });

  final List<MapScanRecord> records;
  final int myScans;
  final int myPins;
  final int allScans;
  final int allPins;
}

class MapScanRepository {
  const MapScanRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<MapScanFeed> getMapScans({required bool includeAll}) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/scan-map',
      query: {'scope': includeAll ? 'all' : 'mine'},
    );
    final responseData = response.data ?? const <String, dynamic>{};
    final items = responseData['data'];
    final counts = _asStringMap(responseData['counts']);

    return MapScanFeed(
      records: items is List
          ? items
                .whereType<Map<String, dynamic>>()
                .map(MapScanRecord.fromJson)
                .map(_asServerRecord)
                .toList()
          : const [],
      myScans: _asInt(counts['my_scans']),
      myPins: _asInt(counts['my_pins']),
      allScans: _asInt(counts['all_scans']),
      allPins: _asInt(counts['all_pins']),
    );
  }

  MapScanRecord _asServerRecord(MapScanRecord record) {
    final serverId = record.serverId ?? record.localId;

    return record.copyWith(
      localId: 'server_$serverId',
      serverId: serverId,
      syncStatus: MapScanRecord.synced,
      locationSource: record.locationSource ?? 'server_scan_record',
    );
  }

  Map<String, dynamic> _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
