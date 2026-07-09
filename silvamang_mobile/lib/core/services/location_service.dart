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

  bool get isFallback => source == 'fallback';

  static DeviceLocation fallback() {
    return DeviceLocation(
      latitude: 9.7392,
      longitude: 118.7353,
      accuracy: 0,
      locationName: 'Brgy. San Roque, Puerto Princesa, Palawan',
      address: 'Puerto Princesa, Palawan',
      timestamp: DateTime.now(),
      source: 'fallback',
    );
  }
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
    final enabled = await isLocationServiceEnabled();
    if (!enabled) {
      return null;
    }

    final allowed = await requestLocationPermission();
    if (!allowed) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      return DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        locationName: 'Current GPS Location',
        address: 'Captured from device GPS',
        timestamp: position.timestamp,
        source: 'gps',
      );
    } catch (_) {
      return null;
    }
  }

  Future<DeviceLocation> getCurrentLocationOrFallback() async {
    return await getCurrentLocation() ?? DeviceLocation.fallback();
  }
}
