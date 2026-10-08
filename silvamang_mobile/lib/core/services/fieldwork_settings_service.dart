import 'dart:convert';

import 'api_client.dart';
import 'local_storage_service.dart';

class FieldworkSettings {
  const FieldworkSettings({this.maximumGpsError = 50, this.distanceMeters = 1});
  final int maximumGpsError;
  final int distanceMeters;

  factory FieldworkSettings.fromJson(Map<String, dynamic> json) {
    final accuracy = json['gps_max_error_m'];
    final distance = json['gps_distance_m'];
    if (accuracy is! int ||
        ![10, 15, 25, 50].contains(accuracy) ||
        distance is! int ||
        ![1, 2, 5, 10].contains(distance)) {
      throw const FormatException('Invalid fieldwork settings');
    }
    return FieldworkSettings(
      maximumGpsError: accuracy,
      distanceMeters: distance,
    );
  }
}

class FieldworkSettingsService {
  FieldworkSettingsService({required this.storage, required this.fetch});
  final LocalStorageService storage;
  final Future<Map<String, dynamic>> Function() fetch;
  static const cacheKey = 'fieldwork_settings_v1';

  factory FieldworkSettingsService.production() => FieldworkSettingsService(
    storage: LocalStorageService.instance,
    fetch: () async {
      final response = await ApiClient.instance.get<Map<String, dynamic>>(
        '/fieldwork-settings',
      );
      return Map<String, dynamic>.from(response.data?['data'] as Map);
    },
  );

  Future<FieldworkSettings> load({required bool online}) async {
    var cached = const FieldworkSettings();
    try {
      final raw = storage.getString(cacheKey);
      if (raw != null) {
        cached = FieldworkSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // Missing or invalid cache keeps the established recording defaults.
    }
    if (!online) return cached;
    try {
      final json = await fetch().timeout(const Duration(seconds: 4));
      final settings = FieldworkSettings.fromJson(json);
      await storage.saveString(cacheKey, jsonEncode(json));
      return settings;
    } catch (_) {
      return cached;
    }
  }
}
