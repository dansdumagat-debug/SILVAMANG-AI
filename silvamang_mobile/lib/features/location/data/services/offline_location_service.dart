import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../map/data/services/offline_map_package_service.dart';
import 'barangay_resolver_service.dart';

final offlineLocationServiceProvider = Provider<OfflineLocationService>((ref) {
  return OfflineLocationService(
    connectivityService: const ConnectivityService(),
    locationService: const LocationService(),
    barangayResolver: ref.read(barangayResolverServiceProvider),
    packageService: ref.read(offlineMapPackageServiceProvider),
  );
});

class OfflineScanLocationResult {
  const OfflineScanLocationResult({
    this.location,
    this.barangay,
    this.manualBarangay,
    required this.locationStatus,
    required this.barangayStatus,
    required this.barangaySource,
    required this.boundaryPackageReady,
    this.message,
  });

  final DeviceLocation? location;
  final String? barangay;
  final String? manualBarangay;
  final String locationStatus;
  final String barangayStatus;
  final String barangaySource;
  final bool boundaryPackageReady;
  final String? message;

  double? get latitude => location?.latitude;
  double? get longitude => location?.longitude;
  double? get accuracy => location?.accuracy;
  DateTime? get timestamp => location?.timestamp;
}

class OfflineLocationService {
  const OfflineLocationService({
    required this.connectivityService,
    required this.locationService,
    required this.barangayResolver,
    required this.packageService,
  });

  final ConnectivityService connectivityService;
  final LocationService locationService;
  final BarangayResolverService barangayResolver;
  final OfflineMapPackageService packageService;

  Future<OfflineScanLocationResult> captureForScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (kDebugMode) {
      debugPrint('SILVAMANG AI offline scan location capture started');
    }

    final locationResult = await locationService.getCurrentLocationResult(
      timeout: timeout,
    );
    final location = locationResult.location;
    if (location == null) {
      return OfflineScanLocationResult(
        locationStatus: locationResult.permissionStatus,
        barangayStatus: 'location_unavailable',
        barangaySource: 'location_unavailable',
        boundaryPackageReady: false,
        message:
            locationResult.errorMessage ??
            'Location unavailable. Please enable GPS/location permission.',
      );
    }

    final hasNetworkConnection = await connectivityService
        .hasNetworkConnection();
    if (hasNetworkConnection) {
      final barangayResolution = await barangayResolver.resolve(
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracy,
      );

      return OfflineScanLocationResult(
        location: location,
        barangay: barangayResolution.barangay,
        locationStatus: 'captured',
        barangayStatus: barangayResolution.message ?? barangayResolution.status,
        barangaySource: barangayResolution.source,
        boundaryPackageReady: false,
        message: barangayResolution.message,
      );
    }

    final packageStatus = await packageService.status();
    if (!packageStatus.canResolveBarangay) {
      return OfflineScanLocationResult(
        location: location,
        locationStatus: 'offline_location_captured',
        barangayStatus: 'offline_package_missing',
        barangaySource: 'location_unavailable',
        boundaryPackageReady: false,
        message:
            'Offline map package not downloaded. Please download the offline map area before field work.',
      );
    }

    final barangayResolution = await barangayResolver.resolve(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      forceOffline: true,
    );

    if (kDebugMode) {
      debugPrint(
        'SILVAMANG AI offline scan location resolved: '
        'barangay=${barangayResolution.barangay ?? 'not_available'}; '
        'source=${barangayResolution.source}; '
        'boundary_ready=${packageStatus.canResolveBarangay}',
      );
    }

    return OfflineScanLocationResult(
      location: location,
      barangay: barangayResolution.barangay,
      locationStatus: 'offline_location_captured',
      barangayStatus: barangayResolution.message ?? barangayResolution.status,
      barangaySource: barangayResolution.source,
      boundaryPackageReady: packageStatus.canResolveBarangay,
      message: packageStatus.canResolveBarangay
          ? barangayResolution.message
          : packageStatus.message,
    );
  }
}
