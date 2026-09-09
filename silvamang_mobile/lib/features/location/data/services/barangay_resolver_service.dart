import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../map/data/services/offline_map_package_service.dart';

final barangayResolverServiceProvider = Provider<BarangayResolverService>((
  ref,
) {
  return const BarangayResolverService();
});

class BarangayResolution {
  const BarangayResolution({
    this.barangay,
    required this.status,
    required this.source,
    this.message,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.timestamp,
    this.polygonMatched = false,
  });

  final String? barangay;
  final String status;
  final String source;
  final String? message;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? timestamp;
  final bool polygonMatched;
}

class BarangayResolverService {
  const BarangayResolverService({
    this.connectivityService = const ConnectivityService(),
    this._dio,
  });

  final ConnectivityService connectivityService;
  final Dio? _dio;

  Dio get _client =>
      _dio ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

  Future<BarangayResolution> resolve({
    required double latitude,
    required double longitude,
    double? accuracy,
    bool forceOffline = false,
  }) async {
    final hasNetworkConnection = forceOffline
        ? false
        : await connectivityService.hasNetworkConnection();
    final resolution = forceOffline
        ? await _resolveFromGeoJson(
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
          )
        : await _resolveWithOnlineFirst(
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            allowOfflineFallback: !hasNetworkConnection,
          );
    final finalResolution = _applyAccuracyNotice(
      resolution: resolution,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );

    if (kDebugMode) {
      debugPrint(
        'SILVAMANG AI barangay result: '
        '${finalResolution.barangay ?? finalResolution.status}; '
        'source=${finalResolution.source}; '
        'lat=$latitude; lon=$longitude; '
        'accuracy=${accuracy ?? 'not_available'}; '
        'polygon_matched=${finalResolution.polygonMatched}; '
        'timestamp=${finalResolution.timestamp?.toIso8601String()}',
      );
    }

    return finalResolution;
  }

  BarangayResolution _applyAccuracyNotice({
    required BarangayResolution resolution,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) {
    if (accuracy == null || accuracy <= 50) {
      return resolution;
    }

    final hasBarangay = resolution.barangay?.trim().isNotEmpty == true;
    if (!hasBarangay) {
      return resolution;
    }

    return BarangayResolution(
      barangay: resolution.barangay,
      status: resolution.status == 'resolved'
          ? 'resolved_low_accuracy'
          : resolution.status,
      source: resolution.source,
      message:
          '${resolution.message ?? 'Barangay resolved.'} GPS accuracy is low, so this barangay may be uncertain.',
      latitude: resolution.latitude ?? latitude,
      longitude: resolution.longitude ?? longitude,
      accuracy: resolution.accuracy ?? accuracy,
      timestamp: resolution.timestamp ?? DateTime.now(),
      polygonMatched: resolution.polygonMatched,
    );
  }

  Future<BarangayResolution> _resolveWithOnlineFirst({
    required double latitude,
    required double longitude,
    double? accuracy,
    required bool allowOfflineFallback,
  }) async {
    final onlineResolution = await _resolveFromOnlineLocation(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );

    if (onlineResolution.source != 'location_unavailable' ||
        !allowOfflineFallback) {
      return onlineResolution;
    }

    return _resolveFromGeoJson(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
  }

  Future<BarangayResolution> _resolveFromOnlineLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    try {
      final response = await _client.getUri(
        Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'jsonv2',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'zoom': '18',
          'addressdetails': '1',
        }),
        options: Options(
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'SILVAMANG AI field app',
          },
        ),
      );

      final data = response.data;
      final address = data is Map ? data['address'] : null;
      if (address is Map) {
        final barangay = _barangayName(address);
        if (barangay != null) {
          return BarangayResolution(
            barangay: barangay,
            status: 'resolved',
            source: 'online_location',
            message: 'Barangay resolved from online location service.',
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            timestamp: DateTime.now(),
          );
        }
      }

      return BarangayResolution(
        status: 'not_found',
        source: 'online_location',
        message: 'Barangay could not be resolved from online location service.',
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        timestamp: DateTime.now(),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI online barangay lookup unavailable: $error');
      }

      return BarangayResolution(
        status: 'online_unavailable',
        source: 'location_unavailable',
        message: 'Online barangay lookup unavailable.',
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        timestamp: DateTime.now(),
      );
    }
  }

  Future<BarangayResolution> _resolveFromGeoJson({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    late final String rawGeoJson;
    try {
      final packageGeoJson = await OfflineMapPackageService()
          .loadBoundaryGeoJson();
      if (packageGeoJson == null) {
        return const BarangayResolution(
          status: 'offline_package_missing',
          source: 'location_unavailable',
          message:
              'Offline map package not downloaded. Download the offline map package before entering areas without internet.',
        );
      }
      rawGeoJson = packageGeoJson;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI offline barangay package missing: $error');
      }
      return const BarangayResolution(
        status: 'offline_package_missing',
        source: 'location_unavailable',
        message:
            'Offline map package not downloaded. Download the offline map package before entering areas without internet.',
      );
    }

    try {
      final decoded = jsonDecode(rawGeoJson);
      if (decoded is! Map<String, dynamic>) {
        return const BarangayResolution(
          status: 'offline_package_invalid',
          source: 'location_unavailable',
          message: 'Offline barangay boundary data is invalid.',
        );
      }

      final features = decoded['features'];
      if (features is! List || features.isEmpty) {
        return const BarangayResolution(
          status: 'offline_package_missing',
          source: 'location_unavailable',
          message:
              'Offline map package not downloaded. Download the offline map package before entering areas without internet.',
        );
      }

      for (final feature in features.whereType<Map>()) {
        final geometry = feature['geometry'];
        final properties = feature['properties'];
        if (geometry is! Map || properties is! Map) {
          continue;
        }

        if (_containsPoint(geometry, latitude, longitude)) {
          final barangay = _barangayName(properties);
          if (barangay != null) {
            return BarangayResolution(
              barangay: barangay,
              status: 'resolved',
              source: 'offline_downloaded_boundary',
              message: 'Barangay resolved from offline downloaded boundary.',
              latitude: latitude,
              longitude: longitude,
              accuracy: accuracy,
              timestamp: DateTime.now(),
              polygonMatched: true,
            );
          }
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI barangay lookup unavailable: $error');
      }
      return const BarangayResolution(
        status: 'offline_package_error',
        source: 'location_unavailable',
        message: 'Offline barangay boundary lookup failed.',
      );
    }

    return BarangayResolution(
      status: 'not_found',
      source: 'offline_downloaded_boundary',
      message: 'Coordinate is outside available barangay boundaries.',
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    );
  }

  bool _containsPoint(Map geometry, double latitude, double longitude) {
    final type = geometry['type']?.toString();
    final coordinates = geometry['coordinates'];

    if (type == 'Polygon' && coordinates is List) {
      return _pointInPolygon(coordinates, latitude, longitude);
    }

    if (type == 'MultiPolygon' && coordinates is List) {
      return coordinates.any(
        (polygon) =>
            polygon is List && _pointInPolygon(polygon, latitude, longitude),
      );
    }

    return false;
  }

  bool _pointInPolygon(List polygon, double latitude, double longitude) {
    if (polygon.isEmpty || polygon.first is! List) {
      return false;
    }

    final outerRing = polygon.first as List;
    if (!_pointInRing(outerRing, latitude, longitude)) {
      return false;
    }

    for (final hole in polygon.skip(1)) {
      if (hole is List && _pointInRing(hole, latitude, longitude)) {
        return false;
      }
    }

    return true;
  }

  bool _pointInRing(List ring, double latitude, double longitude) {
    var isInside = false;
    var previousIndex = ring.length - 1;

    for (var index = 0; index < ring.length; index++) {
      final current = ring[index];
      final previous = ring[previousIndex];
      if (current is! List || previous is! List) {
        previousIndex = index;
        continue;
      }

      final currentLongitude = _asDouble(
        current.isNotEmpty ? current[0] : null,
      );
      final currentLatitude = _asDouble(current.length > 1 ? current[1] : null);
      final previousLongitude = _asDouble(
        previous.isNotEmpty ? previous[0] : null,
      );
      final previousLatitude = _asDouble(
        previous.length > 1 ? previous[1] : null,
      );

      if (currentLongitude == null ||
          currentLatitude == null ||
          previousLongitude == null ||
          previousLatitude == null) {
        previousIndex = index;
        continue;
      }

      final crossesLatitude =
          (currentLatitude > latitude) != (previousLatitude > latitude);
      if (crossesLatitude) {
        final intersectionLongitude =
            (previousLongitude - currentLongitude) *
                (latitude - currentLatitude) /
                (previousLatitude - currentLatitude) +
            currentLongitude;
        if (longitude < intersectionLongitude) {
          isInside = !isInside;
        }
      }

      previousIndex = index;
    }

    return isInside;
  }

  String? _barangayName(Map properties) {
    for (final key in const [
      'barangay',
      'brgy',
      'brgy_name',
      'BRGY_NAME',
      'name',
      'Name',
      'ADM4_EN',
      'ADM4_NAME',
      'village',
      'neighbourhood',
      'neighborhood',
      'suburb',
      'quarter',
      'hamlet',
    ]) {
      final value = properties[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        final normalized = value
            .replaceFirst(RegExp(r'^barangay\s+', caseSensitive: false), '')
            .trim();
        return normalized.isEmpty ? value : normalized;
      }
    }

    return null;
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }
}
