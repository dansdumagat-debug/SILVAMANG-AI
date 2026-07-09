import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../../shared/models/species_model.dart';

final speciesRepositoryProvider = Provider<SpeciesRepository>((ref) {
  return SpeciesRepository(apiClient: ApiClient.instance);
});

class SpeciesRepository {
  const SpeciesRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<SpeciesModel>> getSpecies({
    String? search,
    String? status,
    String? family,
    String? conservationStatus,
  }) async {
    final query = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (family != null && family.isNotEmpty) 'family': family,
      if (conservationStatus != null && conservationStatus.isNotEmpty)
        'conservation_status': conservationStatus,
    };

    final response = await apiClient.get<Map<String, dynamic>>(
      '/species',
      query: query,
    );
    final items = _extractList(response.data);
    return items.map(SpeciesModel.fromJson).toList();
  }

  Future<SpeciesModel> getSpeciesById(int id) async {
    final response = await apiClient.get<Map<String, dynamic>>('/species/$id');
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) {
      return SpeciesModel.fromJson(data);
    }
    return SpeciesModel.fromJson(response.data ?? {});
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic>? responseData) {
    final data = responseData?['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}
