import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service.dart';
import '../../data/services/offline_map_cache_service.dart';
import '../../data/services/offline_map_package_service.dart';

final offlineMapDownloadControllerProvider =
    StateNotifierProvider<
      OfflineMapDownloadController,
      OfflineMapDownloadState
    >((ref) {
      return OfflineMapDownloadController(
        locationService: const LocationService(),
        cacheService: ref.watch(offlineMapCacheServiceProvider),
        packageService: ref.watch(offlineMapPackageServiceProvider),
      );
    });

class OfflineMapDownloadState {
  const OfflineMapDownloadState({
    this.selectedAreaMode = OfflineMapAreaMode.southernLeyte,
    this.selectedRadiusKm = 50,
    this.currentLocation,
    this.cacheStatus,
    this.packageStatus,
    this.progress,
    this.isLoading = false,
    this.isLocating = false,
    this.isDownloading = false,
    this.isCancelling = false,
    this.isClearing = false,
    this.message,
    this.boundaryWarning,
  });

  final OfflineMapAreaMode selectedAreaMode;
  final double selectedRadiusKm;
  final DeviceLocation? currentLocation;
  final OfflineMapCacheStatus? cacheStatus;
  final OfflineMapPackageStatus? packageStatus;
  final OfflineMapDownloadProgress? progress;
  final bool isLoading;
  final bool isLocating;
  final bool isDownloading;
  final bool isCancelling;
  final bool isClearing;
  final String? message;
  final String? boundaryWarning;

  bool get hasLoaded => cacheStatus != null || packageStatus != null;

  bool get packageReady =>
      packageStatus?.canResolveBarangay == true &&
      cacheStatus?.hasCachedTiles == true;

  OfflineMapAreaTarget? get selectedAreaTarget {
    switch (selectedAreaMode) {
      case OfflineMapAreaMode.southernLeyte:
        return OfflineMapAreaTarget.southernLeyte;
      case OfflineMapAreaMode.currentLocation:
        final location = currentLocation;
        if (location == null) {
          return null;
        }

        return OfflineMapAreaTarget(
          name: 'Current GPS area',
          latitude: location.latitude,
          longitude: location.longitude,
          description: 'Map tiles around the phone location right now.',
        );
    }
  }

  String get selectedAreaLabel {
    return selectedAreaTarget?.name ?? 'Current GPS area unavailable';
  }

  OfflineMapDownloadState copyWith({
    OfflineMapAreaMode? selectedAreaMode,
    double? selectedRadiusKm,
    DeviceLocation? currentLocation,
    OfflineMapCacheStatus? cacheStatus,
    OfflineMapPackageStatus? packageStatus,
    OfflineMapDownloadProgress? progress,
    bool? isLoading,
    bool? isLocating,
    bool? isDownloading,
    bool? isCancelling,
    bool? isClearing,
    String? message,
    String? boundaryWarning,
    bool clearLocation = false,
    bool clearProgress = false,
    bool clearBoundaryWarning = false,
  }) {
    return OfflineMapDownloadState(
      selectedAreaMode: selectedAreaMode ?? this.selectedAreaMode,
      selectedRadiusKm: selectedRadiusKm ?? this.selectedRadiusKm,
      currentLocation: clearLocation
          ? null
          : currentLocation ?? this.currentLocation,
      cacheStatus: cacheStatus ?? this.cacheStatus,
      packageStatus: packageStatus ?? this.packageStatus,
      progress: clearProgress ? null : progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      isLocating: isLocating ?? this.isLocating,
      isDownloading: isDownloading ?? this.isDownloading,
      isCancelling: isCancelling ?? this.isCancelling,
      isClearing: isClearing ?? this.isClearing,
      message: message ?? this.message,
      boundaryWarning: clearBoundaryWarning
          ? null
          : boundaryWarning ?? this.boundaryWarning,
    );
  }
}

class OfflineMapDownloadController
    extends StateNotifier<OfflineMapDownloadState> {
  OfflineMapDownloadController({
    required this.locationService,
    required this.cacheService,
    required this.packageService,
  }) : super(const OfflineMapDownloadState());

  final LocationService locationService;
  final OfflineMapCacheService cacheService;
  final OfflineMapPackageService packageService;

  StreamSubscription<OfflineMapDownloadProgress>? _downloadSubscription;
  bool _cancelRequested = false;

  Future<void> ensureLoaded() async {
    if (!state.hasLoaded && !state.isLoading && !state.isDownloading) {
      await loadStatus();
    }

    if (state.currentLocation == null && !state.isLocating) {
      unawaited(refreshCurrentLocation());
    }
  }

  Future<void> loadStatus() async {
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final cacheStatus = await cacheService.status();
      final packageStatus = await packageService.status();

      state = state.copyWith(
        cacheStatus: cacheStatus,
        packageStatus: packageStatus,
        message: !packageStatus.canResolveBarangay
            ? packageStatus.message
            : cacheStatus.message,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        message: 'Offline map status unavailable: $error',
      );
    }
  }

  Future<void> refreshCurrentLocation() async {
    if (state.isLocating) {
      return;
    }

    state = state.copyWith(
      isLocating: true,
      message: state.selectedAreaMode == OfflineMapAreaMode.currentLocation
          ? 'Getting phone GPS location...'
          : state.message,
    );

    try {
      final locationResult = await locationService.getCurrentLocationResult(
        timeout: const Duration(seconds: 12),
      );
      final location = locationResult.location;

      state = state.copyWith(
        currentLocation: location,
        isLocating: false,
        message: location == null
            ? locationResult.errorMessage ??
                  'Phone GPS unavailable. Southern Leyte can still be downloaded.'
            : 'Phone GPS ready. Accuracy ${location.accuracy.toStringAsFixed(1)} meters.',
        clearLocation: location == null,
      );
    } catch (error) {
      state = state.copyWith(
        isLocating: false,
        clearLocation: true,
        message:
            'Phone GPS unavailable. Select Southern Leyte to download a field map package.',
      );
    }
  }

  void setRadius(double radiusKm) {
    if (state.isDownloading || state.isCancelling) {
      return;
    }

    state = state.copyWith(selectedRadiusKm: radiusKm);
  }

  void setAreaMode(OfflineMapAreaMode areaMode) {
    if (state.isDownloading || state.isCancelling) {
      return;
    }

    state = state.copyWith(selectedAreaMode: areaMode);

    if (areaMode == OfflineMapAreaMode.currentLocation &&
        state.currentLocation == null &&
        !state.isLocating) {
      unawaited(refreshCurrentLocation());
    }
  }

  Future<void> startDownload() async {
    if (state.isCancelling) {
      return;
    }

    _cancelRequested = false;
    final target = state.selectedAreaTarget;
    if (target == null) {
      state = state.copyWith(
        message:
            'Current GPS area unavailable. Select Southern Leyte or enable GPS.',
      );
      return;
    }

    await _downloadSubscription?.cancel();
    state = state.copyWith(
      isDownloading: true,
      isCancelling: false,
      message: 'Preparing offline map area...',
      clearProgress: true,
      clearBoundaryWarning: true,
    );

    String? boundaryWarning;
    try {
      await packageService.downloadPackage(
        areaName: target.name,
        centerLatitude: target.latitude,
        centerLongitude: target.longitude,
        radiusKm: state.selectedRadiusKm,
      );
    } catch (_) {
      boundaryWarning =
          'Barangay boundary data is unavailable. Downloading map tiles only.';
      state = state.copyWith(
        message: boundaryWarning,
        boundaryWarning: boundaryWarning,
      );
    }

    if (_cancelRequested) {
      state = state.copyWith(
        progress: const OfflineMapDownloadProgress(
          progress: 0,
          downloadedTiles: 0,
          totalTiles: 0,
          statusMessage: 'Offline map download cancelled.',
          hasError: true,
        ),
        isDownloading: false,
        isCancelling: false,
        message: 'Offline map download cancelled.',
      );
      return;
    }

    final center = LatLng(target.latitude, target.longitude);
    _downloadSubscription = cacheService
        .downloadArea(center: center, radiusKm: state.selectedRadiusKm)
        .listen((progress) {
          final warning = boundaryWarning ?? state.boundaryWarning;
          state = state.copyWith(
            progress: progress,
            message: warning == null
                ? progress.statusMessage
                : '$warning ${progress.statusMessage}',
            isDownloading: !progress.isComplete && !progress.hasError,
          );

          if (progress.isComplete || progress.hasError) {
            unawaited(refreshStatusAfterDownload());
          }
        });
  }

  Future<void> refreshStatusAfterDownload() async {
    _cancelRequested = false;
    try {
      final cacheStatus = await cacheService.status();
      final packageStatus = await packageService.status();
      state = state.copyWith(
        cacheStatus: cacheStatus,
        packageStatus: packageStatus,
        isDownloading: false,
        message: cacheStatus.hasCachedTiles
            ? packageStatus.canResolveBarangay
                  ? 'Offline map downloaded and ready.'
                  : 'Offline map downloaded. Barangay boundary data is still missing.'
            : cacheStatus.message,
      );
    } catch (error) {
      state = state.copyWith(
        isDownloading: false,
        message: 'Offline map status refresh failed: $error',
      );
    }
  }

  Future<void> cancelDownload() async {
    if (!state.isDownloading) {
      return;
    }

    _cancelRequested = true;
    state = state.copyWith(
      isCancelling: true,
      message: 'Cancelling offline map download...',
    );

    try {
      await cacheService.cancelDownload();
      await _downloadSubscription?.cancel();
      final cacheStatus = await cacheService.status();
      final packageStatus = await packageService.status();

      state = state.copyWith(
        cacheStatus: cacheStatus,
        packageStatus: packageStatus,
        progress: const OfflineMapDownloadProgress(
          progress: 0,
          downloadedTiles: 0,
          totalTiles: 0,
          statusMessage: 'Offline map download cancelled.',
          hasError: true,
        ),
        isDownloading: false,
        isCancelling: false,
        message: 'Offline map download cancelled.',
      );
    } catch (error) {
      await _downloadSubscription?.cancel();
      state = state.copyWith(
        isDownloading: false,
        isCancelling: false,
        message: 'Offline map download cancel failed: $error',
      );
    }
  }

  Future<void> clearCache() async {
    await _downloadSubscription?.cancel();
    state = state.copyWith(
      isClearing: true,
      isDownloading: false,
      message: 'Clearing downloaded maps...',
    );

    try {
      await cacheService.clearCache();
      await packageService.deletePackage();

      final cacheStatus = await cacheService.status();
      final packageStatus = await packageService.status();
      state = state.copyWith(
        cacheStatus: cacheStatus,
        packageStatus: packageStatus,
        progress: const OfflineMapDownloadProgress(
          progress: 0,
          downloadedTiles: 0,
          totalTiles: 0,
          statusMessage: 'Downloaded maps cleared.',
        ),
        isClearing: false,
        message: 'Downloaded maps cleared.',
        clearProgress: true,
        clearBoundaryWarning: true,
      );
    } catch (error) {
      state = state.copyWith(
        isClearing: false,
        message: 'Unable to clear downloaded maps: $error',
      );
    }
  }

  @override
  void dispose() {
    unawaited(_downloadSubscription?.cancel());
    super.dispose();
  }
}

enum OfflineMapAreaMode { southernLeyte, currentLocation }

class OfflineMapAreaTarget {
  const OfflineMapAreaTarget({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
  });

  static const southernLeyte = OfflineMapAreaTarget(
    name: 'Southern Leyte',
    latitude: 10.3347,
    longitude: 125.0750,
    description:
        'Prepared field map area for Southern Leyte mangrove monitoring.',
  );

  final String name;
  final double latitude;
  final double longitude;
  final String description;
}
