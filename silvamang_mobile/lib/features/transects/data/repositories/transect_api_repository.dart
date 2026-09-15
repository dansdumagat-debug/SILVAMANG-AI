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
    final response = await apiClient.get<Map<String, dynamic>>(
      '/transects',
      query: const {'scope': 'mine'},
    );
    final data = response.data?['data'];
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map(
          (item) => TransectRecordModel.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
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
