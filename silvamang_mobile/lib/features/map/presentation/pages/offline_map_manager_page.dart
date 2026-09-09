import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../data/services/offline_map_cache_service.dart';
import '../controllers/offline_map_download_controller.dart';

class OfflineMapManagerPage extends ConsumerStatefulWidget {
  const OfflineMapManagerPage({super.key});

  @override
  ConsumerState<OfflineMapManagerPage> createState() =>
      _OfflineMapManagerPageState();
}

class _OfflineMapManagerPageState extends ConsumerState<OfflineMapManagerPage> {
  static const _radiusChoices = <double>[1, 3, 5, 10, 25, 50];

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(offlineMapDownloadControllerProvider.notifier).ensureLoaded(),
    );
  }

  Future<void> _loadStatus() async {
    final controller = ref.read(offlineMapDownloadControllerProvider.notifier);
    await controller.loadStatus();
    unawaited(controller.refreshCurrentLocation());
  }

  Future<void> _downloadArea() async {
    await ref
        .read(offlineMapDownloadControllerProvider.notifier)
        .startDownload();
  }

  Future<void> _clearCache() async {
    await ref.read(offlineMapDownloadControllerProvider.notifier).clearCache();
  }

  Future<void> _cancelDownload() async {
    await ref
        .read(offlineMapDownloadControllerProvider.notifier)
        .cancelDownload();
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(offlineMapDownloadControllerProvider);
    final progress = downloadState.progress?.progress ?? 0;
    final packageReady = downloadState.packageReady;
    final mapTilesReady = downloadState.cacheStatus?.hasCachedTiles == true;
    final selectedTarget = downloadState.selectedAreaTarget;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('Offline Map Manager'),
        backgroundColor: AppColors.mintBackground,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStatus,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              SilvamangCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Package Status',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _areaLabel(downloadState),
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      packageReady
                          ? 'Offline map and barangay lookup ready'
                          : mapTilesReady
                          ? 'Offline map tiles ready; barangay data missing.'
                          : 'Offline map package is not available.',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: packageReady || mapTilesReady
                            ? AppColors.primaryDarkGreen
                            : AppColors.warningOrange,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _StatusLine(
                      label: 'Map tiles',
                      value: downloadState.cacheStatus?.hasCachedTiles == true
                          ? 'Downloaded (${downloadState.cacheStatus!.tileCount} tile(s))'
                          : 'Not downloaded',
                    ),
                    _StatusLine(
                      label: 'Barangay boundaries',
                      value:
                          downloadState.packageStatus?.canResolveBarangay ==
                              true
                          ? '${downloadState.packageStatus!.featureCount} polygon(s)'
                          : 'Not available',
                    ),
                    _StatusLine(
                      label: 'Location lookup data',
                      value:
                          downloadState
                                  .packageStatus
                                  ?.locationLookupAvailable ==
                              true
                          ? 'Available'
                          : 'Not available',
                    ),
                    _StatusLine(
                      label: 'Download center',
                      value: selectedTarget == null
                          ? 'Unavailable'
                          : '${selectedTarget.latitude.toStringAsFixed(6)}, '
                                '${selectedTarget.longitude.toStringAsFixed(6)}',
                    ),
                    _StatusLine(
                      label: 'Phone GPS',
                      value: downloadState.isLocating
                          ? 'Checking location...'
                          : downloadState.currentLocation == null
                          ? 'Unavailable'
                          : '${downloadState.currentLocation!.latitude.toStringAsFixed(6)}, '
                                '${downloadState.currentLocation!.longitude.toStringAsFixed(6)}',
                    ),
                    if (downloadState.message != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        downloadState.message!,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _OfflineAreaMapPreview(
                target: selectedTarget,
                radiusKm: downloadState.selectedRadiusKm,
              ),
              const SizedBox(height: AppSpacing.md),
              SilvamangCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download Offline Map Area',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Map Area', style: AppTextStyles.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Download Southern Leyte before fieldwork. Large areas use faster field-map detail; smaller areas keep more close-up detail.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _AreaChoiceChip(
                          label: 'Southern Leyte',
                          icon: Icons.terrain_rounded,
                          isSelected:
                              downloadState.selectedAreaMode ==
                              OfflineMapAreaMode.southernLeyte,
                          onSelected: downloadState.isDownloading
                              ? null
                              : () => ref
                                    .read(
                                      offlineMapDownloadControllerProvider
                                          .notifier,
                                    )
                                    .setAreaMode(
                                      OfflineMapAreaMode.southernLeyte,
                                    ),
                        ),
                        _AreaChoiceChip(
                          label: 'Current GPS area',
                          icon: Icons.my_location_rounded,
                          isSelected:
                              downloadState.selectedAreaMode ==
                              OfflineMapAreaMode.currentLocation,
                          onSelected: downloadState.isDownloading
                              ? null
                              : () => ref
                                    .read(
                                      offlineMapDownloadControllerProvider
                                          .notifier,
                                    )
                                    .setAreaMode(
                                      OfflineMapAreaMode.currentLocation,
                                    ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed:
                          downloadState.isDownloading ||
                              downloadState.isCancelling ||
                              downloadState.isLocating
                          ? null
                          : () => ref
                                .read(
                                  offlineMapDownloadControllerProvider.notifier,
                                )
                                .refreshCurrentLocation(),
                      icon: Icon(
                        downloadState.isLocating
                            ? Icons.sync_rounded
                            : Icons.gps_fixed_rounded,
                      ),
                      label: Text(
                        downloadState.isLocating
                            ? 'Checking Phone GPS'
                            : 'Refresh Phone GPS',
                      ),
                    ),
                    if (selectedTarget != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        selectedTarget.description,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final radius in _radiusChoices)
                          ChoiceChip(
                            label: Text('${radius.toStringAsFixed(0)} km'),
                            selected: downloadState.selectedRadiusKm == radius,
                            onSelected: downloadState.isDownloading
                                ? null
                                : (_) {
                                    ref
                                        .read(
                                          offlineMapDownloadControllerProvider
                                              .notifier,
                                        )
                                        .setRadius(radius);
                                  },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (downloadState.isDownloading ||
                        downloadState.progress != null) ...[
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        downloadState.progress == null
                            ? 'Preparing...'
                            : '${downloadState.progress!.downloadedTiles}/'
                                  '${downloadState.progress!.totalTiles} tile(s)',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    FilledButton.icon(
                      onPressed:
                          downloadState.isDownloading ||
                              downloadState.isCancelling ||
                              downloadState.isClearing ||
                              selectedTarget == null
                          ? null
                          : _downloadArea,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download Offline Map'),
                    ),
                    if (downloadState.isDownloading ||
                        downloadState.isCancelling) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: downloadState.isCancelling
                            ? null
                            : _cancelDownload,
                        icon: const Icon(Icons.cancel_rounded),
                        label: Text(
                          downloadState.isCancelling
                              ? 'Cancelling Download'
                              : 'Cancel Download',
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed:
                          downloadState.isDownloading ||
                              downloadState.isCancelling ||
                              downloadState.isClearing
                          ? null
                          : _clearCache,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete Offline Map'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                ),
                child: Text(
                  'Barangay auto-fill requires official barangay boundary GeoJSON. '
                  'Add boundaries for every municipality where the app will be used. '
                  'Map tiles alone cannot determine a barangay name.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warningOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _areaLabel(OfflineMapDownloadState state) {
    final status = state.packageStatus;
    final radius = status?.radiusKm;
    if (status?.isDownloaded == true && radius != null) {
      return 'Area: ${status!.areaName}, ${radius.toStringAsFixed(0)} km radius';
    }

    return 'Area: ${state.selectedAreaLabel}, selected radius';
  }
}

class _OfflineAreaMapPreview extends StatelessWidget {
  const _OfflineAreaMapPreview({required this.target, required this.radiusKm});

  final OfflineMapAreaTarget? target;
  final double radiusKm;

  @override
  Widget build(BuildContext context) {
    final center = target == null
        ? const LatLng(12.8797, 121.774)
        : LatLng(target!.latitude, target!.longitude);

    return SilvamangCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 260,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: _zoomForRadius(radiusKm),
                  minZoom: 4,
                  maxZoom: 22,
                ),
                children: [
                  TileLayer(
                    urlTemplate: OfflineMapCacheService.tileUrlTemplate,
                    userAgentPackageName:
                        OfflineMapCacheService.userAgentPackageName,
                    maxZoom: 22,
                    maxNativeZoom: 19,
                  ),
                  TileLayer(
                    urlTemplate: OfflineMapCacheService.labelTileUrlTemplate,
                    userAgentPackageName:
                        OfflineMapCacheService.userAgentPackageName,
                    maxZoom: 22,
                    maxNativeZoom: 19,
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        radius: radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderColor: AppColors.primaryDarkGreen,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 46,
                        height: 46,
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: AppColors.primaryDarkGreen,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      target == null
                          ? 'Select Southern Leyte to download without GPS, or enable GPS to choose your current area.'
                          : '${target!.name} offline area, ${radiusKm.toStringAsFixed(0)} km radius. Scan pins still use phone GPS.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _zoomForRadius(double radiusKm) {
    if (radiusKm <= 1) {
      return 15;
    }
    if (radiusKm <= 3) {
      return 13;
    }
    if (radiusKm <= 10) {
      return 11;
    }
    if (radiusKm <= 25) {
      return 10;
    }
    return 9;
  }
}

class _AreaChoiceChip extends StatelessWidget {
  const _AreaChoiceChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? AppColors.white : AppColors.primaryDarkGreen,
      ),
      selected: isSelected,
      onSelected: onSelected == null ? null : (_) => onSelected!(),
      showCheckmark: false,
      selectedColor: AppColors.primaryDarkGreen,
      backgroundColor: AppColors.softGreen,
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: isSelected ? AppColors.white : AppColors.primaryDarkGreen,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primaryDarkGreen : AppColors.softGreen,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primaryDarkGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
