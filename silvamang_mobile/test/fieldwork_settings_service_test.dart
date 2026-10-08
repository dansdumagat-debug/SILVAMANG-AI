import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:silvamang_mobile/core/services/fieldwork_settings_service.dart';
import 'offline_sync_repository_test.dart' show MemoryQueueStorage;

void main() {
  test('online settings persist and are reused offline', () async {
    final storage = MemoryQueueStorage();
    var calls = 0;
    final service = FieldworkSettingsService(
      storage: storage,
      fetch: () async {
        calls++;
        return {'gps_max_error_m': 15, 'gps_distance_m': 5};
      },
    );
    expect((await service.load(online: true)).maximumGpsError, 15);
    expect((await service.load(online: false)).distanceMeters, 5);
    expect(calls, 1);
  });
  test('invalid server response keeps last working configuration', () async {
    final storage = MemoryQueueStorage();
    await storage.saveString(
      FieldworkSettingsService.cacheKey,
      jsonEncode({'gps_max_error_m': 25, 'gps_distance_m': 2}),
    );
    final service = FieldworkSettingsService(
      storage: storage,
      fetch: () async => {'gps_max_error_m': 0, 'gps_distance_m': 999},
    );
    expect((await service.load(online: true)).maximumGpsError, 25);
  });
  test('network failure and corrupt cache use safe defaults', () async {
    final storage = MemoryQueueStorage();
    await storage.saveString(FieldworkSettingsService.cacheKey, 'broken');
    final service = FieldworkSettingsService(
      storage: storage,
      fetch: () async => throw Exception('offline'),
    );
    final settings = await service.load(online: true);
    expect(settings.maximumGpsError, 50);
    expect(settings.distanceMeters, 1);
  });
}
