import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

final offlineMapCacheServiceProvider = Provider<OfflineMapCacheService>((ref) {
  return OfflineMapCacheService();
});

class OfflineMapCacheStatus {
  const OfflineMapCacheStatus({
    required this.initialized,
    required this.storeReady,
    required this.tileCount,
    required this.sizeKiB,
    required this.message,
  });

  final bool initialized;
  final bool storeReady;
  final int tileCount;
  final double sizeKiB;
  final String message;

  bool get hasCachedTiles => false;
}

class OfflineMapDownloadProgress {
  const OfflineMapDownloadProgress({
    required this.progress,
    required this.downloadedTiles,
    required this.totalTiles,
    required this.statusMessage,
    this.isComplete = false,
    this.hasError = false,
  });

  final double progress;
  final int downloadedTiles;
  final int totalTiles;
  final String statusMessage;
  final bool isComplete;
  final bool hasError;
}

class OfflineMapCacheService {
  OfflineMapCacheService();

  static const storeName = 'silvamang_field_map';
  static const tileUrlTemplate =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const labelTileUrlTemplate =
      'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';
  static const userAgentPackageName = 'com.silvamang.mobile';
  static const minDownloadZoom = 12;
  static const maxDownloadZoom = 16;

  Future<void> initialize() async {}

  TileProvider tileProvider({required bool isOnline}) {
    return NetworkTileProvider();
  }

  Future<OfflineMapCacheStatus> status() async {
    return const OfflineMapCacheStatus(
      initialized: false,
      storeReady: false,
      tileCount: 0,
      sizeKiB: 0,
      message: 'Offline map caching is available on Android field devices.',
    );
  }

  Stream<OfflineMapDownloadProgress> downloadArea({
    required LatLng center,
    required double radiusKm,
  }) async* {
    yield const OfflineMapDownloadProgress(
      progress: 0,
      downloadedTiles: 0,
      totalTiles: 0,
      statusMessage:
          'Offline map download is available on Android field devices.',
      hasError: true,
    );
  }

  Future<void> clearCache() async {}

  Future<void> cancelDownload() async {}
}
