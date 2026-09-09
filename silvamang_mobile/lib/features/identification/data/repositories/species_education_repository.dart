import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../core/services/api_client.dart';
import '../models/species_education_model.dart';

class SpeciesEducationRepository {
  SpeciesEducationRepository._();

  static final instance = SpeciesEducationRepository._();

  static const _assetPath = 'assets/data/mangrove_education.json';
  static const _onlineTimeout = Duration(seconds: 3);

  Map<String, SpeciesEducationModel>? _cache;
  final Map<String, SpeciesEducationModel> _onlineCache = {};

  Future<SpeciesEducationModel> findByScientificName(String name) async {
    final key = SpeciesEducationModel.normalizedKey(name);
    final entries = await _loadEntries();
    final localEducation = entries[key] ?? SpeciesEducationModel.fallback(name);

    if (_onlineCache.containsKey(key)) {
      return _onlineCache[key]!;
    }

    try {
      final response = await ApiClient.instance.get<Map<String, dynamic>>(
        '/mangrove-education',
        query: {'species_name': name.replaceAll('_', ' ')},
      ).timeout(_onlineTimeout);
      final payload = _educationPayload(response.data);
      if (payload != null) {
        final onlineEducation = SpeciesEducationModel.fromJson(payload);
        if (onlineEducation.hasUsefulContent) {
          _onlineCache[key] = onlineEducation;
          return onlineEducation;
        }
      }
    } catch (_) {
      // Keep the result page useful offline or while the Laravel API is down.
    }

    return localEducation;
  }

  Future<Map<String, SpeciesEducationModel>> _loadEntries() async {
    if (_cache != null) {
      return _cache!;
    }

    try {
      final rawJson = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) {
        _cache = const {};
        return _cache!;
      }

      final entries = <String, SpeciesEducationModel>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final json = item.map((key, value) => MapEntry(key.toString(), value));
        final model = SpeciesEducationModel.fromJson(json);
        final names = [
          model.scientificName,
          model.displayName,
          model.scientificName.replaceAll('_', ' '),
          model.displayName.replaceAll(' ', '_'),
        ];

        for (final name in names) {
          final key = SpeciesEducationModel.normalizedKey(name);
          if (key.isNotEmpty) {
            entries[key] = model;
          }
        }
      }

      _cache = entries;
      return entries;
    } catch (_) {
      _cache = const {};
      return _cache!;
    }
  }
}

Map<String, dynamic>? _educationPayload(Object? data) {
  if (data is! Map) {
    return null;
  }

  final payload = data['data'];
  final source = payload is Map ? payload : data;

  return source.map((key, value) => MapEntry(key.toString(), value));
}
