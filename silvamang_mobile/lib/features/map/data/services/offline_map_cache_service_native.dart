import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
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

  bool get hasCachedTiles => storeReady && tileCount > 0;
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
  static const minDownloadZoom = 9;
  static const maxDownloadZoom = 16;
  static const _downloadedTileCountKey = 'last_download_tile_count';
  static const _downloadedAtKey = 'last_downloaded_at';
  static const _downloadCenterLatitudeKey = 'last_download_center_latitude';
  static const _downloadCenterLongitudeKey = 'last_download_center_longitude';
  static const _downloadRadiusKmKey = 'last_download_radius_km';
  static const _downloadMinZoomKey = 'last_download_min_zoom';
  static const _downloadMaxZoomKey = 'last_download_max_zoom';

  bool _initialized = false;
  bool _cancelDownloadRequested = false;

  FMTCStore get _store => const FMTCStore(storeName);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    if (kIsWeb) {
      return;
    }

    try {
      await FMTCObjectBoxBackend().initialise();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SILVAMANG AI offline map backend init note: $error');
      }
    }

    final isReady = await _store.manage.ready;
    if (!isReady) {
      await _store.manage.create();
    }

    _initialized = true;
  }

  TileProvider tileProvider({required bool isOnline}) {
    if (kIsWeb) {
      return NetworkTileProvider();
    }

    return FMTCTileProvider(
      stores: {
        storeName: isOnline
            ? BrowseStoreStrategy.readUpdateCreate
            : BrowseStoreStrategy.read,
      },
      loadingStrategy: isOnline
          ? BrowseLoadingStrategy.cacheFirst
          : BrowseLoadingStrategy.cacheOnly,
    );
  }

  Future<OfflineMapCacheStatus> status() async {
    if (kIsWeb) {
      return const OfflineMapCacheStatus(
        initialized: false,
        storeReady: false,
        tileCount: 0,
        sizeKiB: 0,
        message: 'Offline map caching is available on Android field devices.',
      );
    }

    try {
      await initialize();
      final stats = await _store.stats.all;
      final metadata = await _store.metadata.read;
      final recordedTileCount = int.tryParse(
        metadata[_downloadedTileCountKey] ?? '',
      );
      final effectiveTileCount = stats.length > 0
          ? stats.length
          : recordedTileCount ?? 0;

      return OfflineMapCacheStatus(
        initialized: true,
        storeReady: true,
        tileCount: effectiveTileCount,
        sizeKiB: stats.size,
        message: effectiveTileCount > 0
            ? 'Offline map cache ready.'
            : 'No offline map area downloaded yet.',
      );
    } catch (error) {
      return OfflineMapCacheStatus(
        initialized: _initialized,
        storeReady: false,
        tileCount: 0,
        sizeKiB: 0,
        message: 'Offline map cache unavailable: $error',
      );
    }
  }

  Stream<OfflineMapDownloadProgress> downloadArea({
    required LatLng center,
    required double radiusKm,
  }) async* {
    if (kIsWeb) {
      yield const OfflineMapDownloadProgress(
        progress: 0,
        downloadedTiles: 0,
        totalTiles: 0,
        statusMessage:
            'Offline map download is available on Android field devices.',
        hasError: true,
      );
      return;
    }

    try {
      _cancelDownloadRequested = false;
      await initialize();
      final zoomRange = _zoomRangeForRadiusKm(radiusKm);
      final region = CircleRegion(center, radiusKm).toDownloadable(
        minZoom: zoomRange.minZoom,
        maxZoom: zoomRange.maxZoom,
        options: TileLayer(
          urlTemplate: tileUrlTemplate,
          userAgentPackageName: userAgentPackageName,
        ),
      );
      final totalTiles = await _store.download.countTiles(region);
      yield OfflineMapDownloadProgress(
        progress: 0,
        downloadedTiles: 0,
        totalTiles: totalTiles,
        statusMessage:
            'Preparing $totalTiles satellite tile(s), zoom ${zoomRange.minZoom}-${zoomRange.maxZoom}...',
      );

      final download = _store.download.startForeground(
        region: region,
        parallelThreads: 6,
        skipExistingTiles: true,
      );

      var downloadedTileCount = 0;
      await for (final progress in download.downloadProgress) {
        downloadedTileCount =
            progress.successfulTilesCount + progress.existingTilesCount;
        yield OfflineMapDownloadProgress(
          progress: progress.percentageProgress.clamp(0, 100) / 100,
          downloadedTiles: downloadedTileCount,
          totalTiles: progress.maxTilesCount,
          statusMessage:
              'Downloaded ${progress.successfulTilesCount} tile(s), '
              '${progress.existingTilesCount} already cached.',
        );
      }

      if (_cancelDownloadRequested) {
        _cancelDownloadRequested = false;
        yield const OfflineMapDownloadProgress(
          progress: 0,
          downloadedTiles: 0,
          totalTiles: 0,
          statusMessage: 'Offline map download cancelled.',
          hasError: true,
        );
        return;
      }

      final recordedTileCount = downloadedTileCount > 0
          ? downloadedTileCount
          : totalTiles;
      if (recordedTileCount > 0) {
        await _writeSuccessfulDownloadMetadata(
          center: center,
          radiusKm: radiusKm,
          zoomRange: zoomRange,
          tileCount: recordedTileCount,
        );
      }

      yield OfflineMapDownloadProgress(
        progress: 1,
        downloadedTiles: recordedTileCount,
        totalTiles: totalTiles,
        statusMessage: 'Offline map area downloaded.',
        isComplete: true,
      );
    } catch (error) {
      yield OfflineMapDownloadProgress(
        progress: 0,
        downloadedTiles: 0,
        totalTiles: 0,
        statusMessage: 'Offline map download failed: $error',
        hasError: true,
      );
    }
  }

  Future<void> clearCache() async {
    if (kIsWeb) {
      return;
    }

    await initialize();
    await _store.manage.reset();
    await _store.metadata.reset();
  }

  Future<void> cancelDownload() async {
    if (kIsWeb) {
      return;
    }

    _cancelDownloadRequested = true;
    await initialize();
    await _store.download.cancel();
  }

  Future<void> _writeSuccessfulDownloadMetadata({
    required LatLng center,
    required double radiusKm,
    required _DownloadZoomRange zoomRange,
    required int tileCount,
  }) async {
    await _store.metadata.setBulk(
      kvs: {
        _downloadedTileCountKey: tileCount.toString(),
        _downloadedAtKey: DateTime.now().toIso8601String(),
        _downloadCenterLatitudeKey: center.latitude.toString(),
        _downloadCenterLongitudeKey: center.longitude.toString(),
        _downloadRadiusKmKey: radiusKm.toString(),
        _downloadMinZoomKey: zoomRange.minZoom.toString(),
        _downloadMaxZoomKey: zoomRange.maxZoom.toString(),
      },
    );
  }

  _DownloadZoomRange _zoomRangeForRadiusKm(double radiusKm) {
    if (radiusKm >= 50) {
      return const _DownloadZoomRange(minZoom: 9, maxZoom: 13);
    }

    if (radiusKm >= 25) {
      return const _DownloadZoomRange(minZoom: 10, maxZoom: 14);
    }

    if (radiusKm >= 10) {
      return const _DownloadZoomRange(minZoom: 11, maxZoom: 15);
    }

    return const _DownloadZoomRange(minZoom: 12, maxZoom: 16);
  }
}

class _DownloadZoomRange {
  const _DownloadZoomRange({required this.minZoom, required this.maxZoom});

  final int minZoom;
  final int maxZoom;
}
