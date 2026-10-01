import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../models/transect_record_model.dart';

final transectApiRepositoryProvider = Provider<TransectApiRepository>((ref) {
  return TransectApiRepository(apiClient: ApiClient.instance);
});

class TransectApiRepository {
  const TransectApiRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<TransectRecordModel>> getMine() async {
    // Synchronize every page into the existing offline cache, in bounded batches.
    final records = <String, TransectRecordModel>{};
    var page = 1;
    var lastPage = 1;
    do {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/transects',
        query: {'scope': 'mine', 'page': page, 'per_page': 50},
      );
      final data = response.data?['data'];
      if (data is! List) {
        throw const ApiException('Invalid transect history response.');
      }
      for (final item in data.whereType<Map>()) {
        final record = TransectRecordModel.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
        records[record.localId] = record;
      }
      final meta = response.data?['meta'];
      lastPage = meta is Map ? (meta['last_page'] as num?)?.toInt() ?? 1 : 1;
      page++;
    } while (page <= lastPage);
    return records.values.toList();
  }

  Future<TransectRecordModel> save(TransectRecordModel transect) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/transects',
      data: transect.toApiPayload(),
    );
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) {
      return TransectRecordModel.fromJson(data);
    }
    if (data is Map) {
      return TransectRecordModel.fromJson(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    throw const ApiException(
      'Transect saved, but the server response was invalid.',
    );
  }

  Future<void> delete(String serverId) async {
    await apiClient.delete<Map<String, dynamic>>('/transects/$serverId');
  }
}
