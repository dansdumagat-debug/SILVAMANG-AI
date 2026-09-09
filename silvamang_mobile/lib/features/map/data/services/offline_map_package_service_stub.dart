import 'package:flutter_riverpod/flutter_riverpod.dart';

final offlineMapPackageServiceProvider = Provider<OfflineMapPackageService>((
  ref,
) {
  return const OfflineMapPackageService();
});

class OfflineMapPackageStatus {
  const OfflineMapPackageStatus({
    required this.isDownloaded,
    required this.mapTilesAvailable,
    required this.barangayBoundariesAvailable,
    required this.locationLookupAvailable,
    required this.featureCount,
    required this.status,
    required this.message,
    this.areaName = OfflineMapPackageService.areaName,
    this.assetPath = OfflineMapPackageService.boundaryAssetPath,
    this.localPath,
    this.downloadedAt,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusKm,
  });

  final bool isDownloaded;
  final bool mapTilesAvailable;
  final bool barangayBoundariesAvailable;
  final bool locationLookupAvailable;
  final int featureCount;
  final String status;
  final String message;
  final String areaName;
  final String assetPath;
  final String? localPath;
  final DateTime? downloadedAt;
  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusKm;

  bool get canResolveBarangay =>
      isDownloaded && barangayBoundariesAvailable && locationLookupAvailable;
}

class OfflineMapPackageService {
  const OfflineMapPackageService();

  static const areaName = 'Selected field area';
  static const boundaryAssetPath = 'assets/geo/barangay_boundaries.geojson';

  Future<bool> isPackageAvailable() async => false;

  Future<void> downloadPackage({
    String areaName = OfflineMapPackageService.areaName,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
  }) async {
    throw StateError(
      'Offline map package download is available on Android field devices.',
    );
  }

  Future<void> deletePackage() async {}

  Future<double> downloadProgress() async => 0;

  Future<String?> loadBoundaryGeoJson() async => null;

  Future<OfflineMapPackageStatus> status() async {
    return const OfflineMapPackageStatus(
      isDownloaded: false,
      mapTilesAvailable: false,
      barangayBoundariesAvailable: false,
      locationLookupAvailable: false,
      featureCount: 0,
      status: 'unsupported_platform',
      message:
          'Offline map package download is available on Android field devices.',
    );
  }
}
