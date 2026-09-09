import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class DeviceLocation {
  const DeviceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.locationName,
    required this.address,
    required this.timestamp,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final String locationName;
  final String address;
  final DateTime timestamp;
  final String source;
}

class DeviceLocationResult {
  const DeviceLocationResult({
    this.location,
    this.errorMessage,
    this.permissionStatus = '',
  });

  final DeviceLocation? location;
  final String? errorMessage;
  final String permissionStatus;

  bool get hasLocation => location != null;
}

class LocationService {
  const LocationService();

  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<DeviceLocation?> getCurrentLocation() async {
    final result = await getCurrentLocationResult();
    return result.location;
  }

  Future<DeviceLocationResult> getCurrentLocationResult({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (kDebugMode) {
      debugPrint('SILVAMANG AI location request started');
    }

    final enabled = await isLocationServiceEnabled();
    if (!enabled) {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI location failure reason: GPS disabled');
      }
      return const DeviceLocationResult(
        errorMessage: 'Location service is disabled. Please enable GPS.',
        permissionStatus: 'service_disabled',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (kDebugMode) {
      debugPrint('SILVAMANG AI location permission status: $permission');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (kDebugMode) {
        debugPrint('SILVAMANG AI location permission status: $permission');
      }
    }

    if (permission == LocationPermission.denied) {
      return const DeviceLocationResult(
        errorMessage: 'Location permission denied.',
        permissionStatus: 'denied',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const DeviceLocationResult(
        errorMessage:
            'Location permission is permanently denied. Enable it in app settings.',
        permissionStatus: 'denied_forever',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: timeout,
        ),
      );

      final location = DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        locationName: 'Current GPS Location',
        address: 'Captured from device GPS',
        timestamp: position.timestamp,
        source: 'gps',
      );

      if (kDebugMode) {
        debugPrint(
          'SILVAMANG AI latitude/longitude captured: '
          '${location.latitude}, ${location.longitude}',
        );
        debugPrint('SILVAMANG AI location accuracy: ${location.accuracy}');
      }

      return DeviceLocationResult(
        location: location,
        permissionStatus: permission.name,
      );
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI location failure reason: timeout');
      }
      return const DeviceLocationResult(
        errorMessage: 'Location request timed out.',
        permissionStatus: 'timeout',
      );
    } catch (_) {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI location failure reason: unavailable');
      }
      return const DeviceLocationResult(
        errorMessage: 'Location unavailable. Please try again.',
        permissionStatus: 'unavailable',
      );
    }
  }
}
