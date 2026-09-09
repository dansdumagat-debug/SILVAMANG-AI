import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final offlineMapPackageServiceProvider = Provider<OfflineMapPackageService>((
  ref,
) {
  return OfflineMapPackageService();
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
  OfflineMapPackageService();

  static const areaName = 'Selected field area';
  static const boundaryAssetPath = 'assets/geo/barangay_boundaries.geojson';
  static const _packageDirectoryName = 'silvamang_offline_map_package';
  static const _boundaryFileName = 'barangay_boundaries.geojson';
  static const _metadataFileName = 'location_lookup_metadata.json';

  double _lastDownloadProgress = 0;

  Future<bool> isPackageAvailable() async {
    return (await status()).canResolveBarangay;
  }

  Future<void> downloadPackage({
    String areaName = OfflineMapPackageService.areaName,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
  }) async {
    _lastDownloadProgress = 0.05;

    final rawGeoJson = await rootBundle.loadString(boundaryAssetPath);
    final featureCount = _featureCount(rawGeoJson);
    if (featureCount == 0) {
      _lastDownloadProgress = 0;
      throw StateError(
        'Barangay boundary data is unavailable. Please add official boundary data.',
      );
    }

    _lastDownloadProgress = 0.35;
    final directory = await _packageDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final boundaryFile = await _boundaryFile();
    await boundaryFile.writeAsString(rawGeoJson, flush: true);

    _lastDownloadProgress = 0.75;
    final downloadedAt = DateTime.now();
    final metadataFile = await _metadataFile();
    await metadataFile.writeAsString(
      jsonEncode({
        'area_name': areaName,
        'center_latitude': centerLatitude,
        'center_longitude': centerLongitude,
        'radius_km': radiusKm,
        'boundary_asset_path': boundaryAssetPath,
        'boundary_file_name': _boundaryFileName,
        'feature_count': featureCount,
        'downloaded_at': downloadedAt.toIso8601String(),
        'contains': [
          'map_tiles',
          'barangay_boundaries',
          'location_lookup_data',
        ],
      }),
      flush: true,
    );

    _lastDownloadProgress = 1;

    if (kDebugMode) {
      debugPrint(
        'SILVAMANG AI offline map package downloaded: '
        'features=$featureCount; path=${boundaryFile.path}',
      );
    }
  }

  Future<void> deletePackage() async {
    final directory = await _packageDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    _lastDownloadProgress = 0;
  }

  Future<double> downloadProgress() async {
    return _lastDownloadProgress;
  }

  Future<String?> loadBoundaryGeoJson() async {
    final boundaryFile = await _boundaryFile();
    if (!await boundaryFile.exists()) {
      return null;
    }

    return boundaryFile.readAsString();
  }

  Future<OfflineMapPackageStatus> status() async {
    try {
      final boundaryFile = await _boundaryFile();
      if (!await boundaryFile.exists()) {
        return const OfflineMapPackageStatus(
          isDownloaded: false,
          mapTilesAvailable: false,
          barangayBoundariesAvailable: false,
          locationLookupAvailable: false,
          featureCount: 0,
          status: 'not_downloaded',
          message: 'Offline map package is not available.',
        );
      }

      final rawGeoJson = await boundaryFile.readAsString();
      final featureCount = _featureCount(rawGeoJson);
      if (featureCount == 0) {
        return OfflineMapPackageStatus(
          isDownloaded: false,
          mapTilesAvailable: false,
          barangayBoundariesAvailable: false,
          locationLookupAvailable: false,
          featureCount: 0,
          status: 'boundary_unavailable',
          message:
              'Barangay boundary data is unavailable. Please add official boundary data.',
          localPath: boundaryFile.path,
        );
      }

      final metadata = await _readMetadata();
      final downloadedAtText = metadata?['downloaded_at']?.toString();
      final areaNameText = metadata?['area_name']?.toString();

      return OfflineMapPackageStatus(
        isDownloaded: true,
        mapTilesAvailable: true,
        barangayBoundariesAvailable: true,
        locationLookupAvailable: true,
        featureCount: featureCount,
        status: 'ready',
        message: 'Offline package ready.',
        areaName: areaNameText == null || areaNameText.trim().isEmpty
            ? areaName
            : areaNameText,
        localPath: boundaryFile.path,
        downloadedAt: downloadedAtText == null
            ? null
            : DateTime.tryParse(downloadedAtText),
        centerLatitude: _asDouble(metadata?['center_latitude']),
        centerLongitude: _asDouble(metadata?['center_longitude']),
        radiusKm: _asDouble(metadata?['radius_km']),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI offline map package unavailable: $error');
      }

      return OfflineMapPackageStatus(
        isDownloaded: false,
        mapTilesAvailable: false,
        barangayBoundariesAvailable: false,
        locationLookupAvailable: false,
        featureCount: 0,
        status: 'error',
        message: 'Offline map package unavailable: $error',
      );
    }
  }

  Future<Directory> _packageDirectory() async {
    final baseDirectory = await getApplicationDocumentsDirectory();
    return Directory(
      '${baseDirectory.path}${Platform.pathSeparator}$_packageDirectoryName',
    );
  }

  Future<File> _boundaryFile() async {
    final directory = await _packageDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_boundaryFileName');
  }

  Future<File> _metadataFile() async {
    final directory = await _packageDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_metadataFileName');
  }

  Future<Map<String, dynamic>?> _readMetadata() async {
    final file = await _metadataFile();
    if (!await file.exists()) {
      return null;
    }

    final decoded = jsonDecode(await file.readAsString());
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  int _featureCount(String rawGeoJson) {
    try {
      final decoded = jsonDecode(rawGeoJson);
      if (decoded is! Map<String, dynamic>) {
        return 0;
      }
      final features = decoded['features'];
      return features is List ? features.length : 0;
    } catch (_) {
      return 0;
    }
  }

  double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}
