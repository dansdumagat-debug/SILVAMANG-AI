import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../data/services/offline_map_cache_service.dart';

class OfflineMapDownloadPage extends ConsumerStatefulWidget {
  const OfflineMapDownloadPage({super.key});

  @override
  ConsumerState<OfflineMapDownloadPage> createState() =>
      _OfflineMapDownloadPageState();
}

class _OfflineMapDownloadPageState
    extends ConsumerState<OfflineMapDownloadPage> {
  static const _radiusOptions = <double>[1, 3, 5, 10, 25, 50];

  final LocationService _locationService = const LocationService();
  StreamSubscription<OfflineMapDownloadProgress>? _downloadSubscription;

  DeviceLocation? _currentLocation;
  OfflineMapCacheStatus? _cacheStatus;
  OfflineMapDownloadProgress? _progress;
  double _selectedRadiusKm = 3;
  bool _isLocating = false;
  bool _isDownloading = false;
  bool _isClearing = false;
  String _statusMessage =
      'Select an area around your current municipality or field location.';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadCacheStatus();
      await _captureCurrentLocation();
    });
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCacheStatus() async {
    final status = await ref.read(offlineMapCacheServiceProvider).status();
    if (!mounted) {
      return;
    }
    setState(() {
      _cacheStatus = status;
      _statusMessage = status.message;
    });
  }

  Future<void> _captureCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _statusMessage = 'Getting current location...';
    });

    final result = await _locationService.getCurrentLocationResult(
      timeout: const Duration(seconds: 8),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _currentLocation = result.location;
      _isLocating = false;
      _statusMessage = result.location == null
          ? result.errorMessage ?? 'Current location unavailable.'
          : 'Current location ready. Choose a radius to download.';
    });
  }

  void _startDownload() {
    final location = _currentLocation;
    if (location == null) {
      setState(() {
        _statusMessage = 'Current location unavailable.';
      });
      return;
    }

    _downloadSubscription?.cancel();
    setState(() {
      _isDownloading = true;
      _progress = null;
      _statusMessage = 'Starting offline map download...';
    });

    _downloadSubscription = ref
        .read(offlineMapCacheServiceProvider)
        .downloadArea(
          center: LatLng(location.latitude, location.longitude),
          radiusKm: _selectedRadiusKm,
        )
        .listen((progress) async {
          if (!mounted) {
            return;
          }

          setState(() {
            _progress = progress;
            _statusMessage = progress.statusMessage;
            _isDownloading = !progress.isComplete && !progress.hasError;
          });

          if (progress.isComplete || progress.hasError) {
            await _loadCacheStatus();
          }
        });
  }

  Future<void> _clearCache() async {
    setState(() {
      _isClearing = true;
      _statusMessage = 'Clearing downloaded maps...';
    });

    await ref.read(offlineMapCacheServiceProvider).clearCache();
    await _loadCacheStatus();

    if (!mounted) {
      return;
    }
    setState(() {
      _isClearing = false;
      _progress = null;
      _statusMessage = 'Downloaded maps cleared.';
    });
  }

  Future<void> _cancelDownload() async {
    setState(() {
      _statusMessage = 'Cancelling offline map download...';
    });

    await ref.read(offlineMapCacheServiceProvider).cancelDownload();
    await _downloadSubscription?.cancel();
    await _loadCacheStatus();

    if (!mounted) {
      return;
    }

    setState(() {
      _isDownloading = false;
      _progress = const OfflineMapDownloadProgress(
        progress: 0,
        downloadedTiles: 0,
        totalTiles: 0,
        statusMessage: 'Offline map download cancelled.',
        hasError: true,
      );
      _statusMessage = 'Offline map download cancelled.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressValue = _progress?.progress ?? 0;
    final cacheStatus = _cacheStatus;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(fallbackRouteName: RouteNames.map),
        title: const Text('Download Offline Map Area'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.screenPadding),
        children: [
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Area', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  label: 'Latitude',
                  value: _currentLocation?.latitude.toStringAsFixed(6) ?? '-',
                ),
                _InfoRow(
                  label: 'Longitude',
                  value: _currentLocation?.longitude.toStringAsFixed(6) ?? '-',
                ),
                _InfoRow(
                  label: 'Accuracy',
                  value: _currentLocation == null
                      ? '-'
                      : '${_currentLocation!.accuracy.toStringAsFixed(1)} m',
                ),
                const SizedBox(height: AppSpacing.md),
                SilvamangButton(
                  text: 'Refresh Location',
                  icon: Icons.my_location_rounded,
                  type: SilvamangButtonType.outline,
                  isLoading: _isLocating,
                  onPressed: _isDownloading ? null : _captureCurrentLocation,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Download Radius', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final radius in _radiusOptions)
                      ChoiceChip(
                        label: Text('${radius.toStringAsFixed(0)} km'),
                        selected: _selectedRadiusKm == radius,
                        onSelected: _isDownloading
                            ? null
                            : (_) => setState(() => _selectedRadiusKm = radius),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(value: progressValue),
                const SizedBox(height: AppSpacing.sm),
                Text(_statusMessage, style: AppTextStyles.bodyMedium),
                if (_progress != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_progress!.downloadedTiles}/${_progress!.totalTiles} tiles',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SilvamangButton(
                  text: 'Download Map Area',
                  icon: Icons.download_rounded,
                  isLoading: _isDownloading,
                  onPressed: _currentLocation == null || _isClearing
                      ? null
                      : _startDownload,
                ),
                if (_isDownloading) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SilvamangButton(
                    text: 'Cancel Download',
                    icon: Icons.cancel_rounded,
                    type: SilvamangButtonType.outline,
                    onPressed: _cancelDownload,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cache Status', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  label: 'Tiles',
                  value: cacheStatus?.tileCount.toString() ?? '-',
                ),
                _InfoRow(
                  label: 'Size',
                  value: cacheStatus == null
                      ? '-'
                      : '${(cacheStatus.sizeKiB / 1024).toStringAsFixed(2)} MB',
                ),
                _InfoRow(
                  label: 'Status',
                  value: cacheStatus?.message ?? 'Checking cache...',
                ),
                const SizedBox(height: AppSpacing.md),
                SilvamangButton(
                  text: 'Clear Downloaded Maps',
                  icon: Icons.delete_outline_rounded,
                  type: SilvamangButtonType.outline,
                  isLoading: _isClearing,
                  onPressed: _isDownloading ? null : _clearCache,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.labelLarge,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
