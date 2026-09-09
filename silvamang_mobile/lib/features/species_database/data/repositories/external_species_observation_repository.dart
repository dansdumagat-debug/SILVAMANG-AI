import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/local_storage_service.dart';
import '../models/external_species_observation_model.dart';

final externalSpeciesObservationRepositoryProvider =
    Provider<ExternalSpeciesObservationRepository>((ref) {
      return ExternalSpeciesObservationRepository(
        apiClient: ApiClient.instance,
        storage: LocalStorageService.instance,
      );
    });

class ExternalSpeciesObservationRepository {
  const ExternalSpeciesObservationRepository({
    required this.apiClient,
    required this.storage,
  });

  final ApiClient apiClient;
  final LocalStorageService storage;

  Future<ExternalSpeciesReferenceResult> getReferences({
    int? speciesId,
    required String speciesName,
    bool refresh = false,
    int limit = 8,
  }) async {
    final cleanName = speciesName.replaceAll('_', ' ').trim();
    if (cleanName.isEmpty) {
      return ExternalSpeciesReferenceResult.unavailable(speciesName);
    }

    final cachedResult = _readCached(cleanName);

    try {
      final path = speciesId != null && speciesId > 0
          ? '/species/$speciesId/external-observations'
          : '/external-species-observations';
      final response = await apiClient.get<Map<String, dynamic>>(
        path,
        query: {
          'limit': limit,
          if (refresh) 'refresh': true,
          if (speciesId == null || speciesId <= 0) 'species_name': cleanName,
        },
      );

      final data = response.data ?? {};
      final result = ExternalSpeciesReferenceResult.fromJson(data);
      if (result.hasObservations) {
        await storage.saveString(_cacheKey(cleanName), jsonEncode(data));
      }

      return result;
    } catch (_) {
      return cachedResult ?? ExternalSpeciesReferenceResult.unavailable(cleanName);
    }
  }

  ExternalSpeciesReferenceResult? _readCached(String speciesName) {
    final raw = storage.getString(_cacheKey(speciesName));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ExternalSpeciesReferenceResult.fromJson(decoded);
      }
      if (decoded is Map) {
        return ExternalSpeciesReferenceResult.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _cacheKey(String speciesName) {
    final normalized = speciesName
        .replaceAll('_', ' ')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_');

    return 'external_species_references_$normalized';
  }
}
