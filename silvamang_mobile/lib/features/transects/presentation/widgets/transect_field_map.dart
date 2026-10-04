import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../map/data/services/offline_map_cache_service.dart';
import '../../../map/presentation/controllers/offline_map_download_controller.dart';
import '../../data/models/transect_observation_model.dart';
import '../../data/models/transect_point_model.dart';

enum TransectMapLayer { satellite, street }

class TransectFieldMap extends ConsumerWidget {
  static String labelFor(String name, [String? code]) {
    final named = RegExp(
      r'\b(?:transect|t)\s*[-#]?\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(name);
    final coded = RegExp(r'-(\d+)$').firstMatch(code ?? '');
    final number = named?.group(1) ?? coded?.group(1);
    return number == null ? 'T1' : 'T${int.parse(number)}';
  }

  const TransectFieldMap({
    super.key,
    required this.mapController,
    required this.points,
    this.segments,
    this.transectLabel = 'T1',
    required this.observations,
    required this.isOnline,
    required this.layer,
    this.currentLocation,
    this.onMapTap,
    this.onObservationTap,
    this.lineColor = AppColors.primaryGreen,
  });

  final MapController mapController;
  final List<TransectPointModel> points;
  final List<List<TransectPointModel>>? segments;
  final String transectLabel;
  final List<TransectObservationModel> observations;
  final LatLng? currentLocation;
  final bool isOnline;
  final TransectMapLayer layer;
  final ValueChanged<LatLng>? onMapTap;
  final ValueChanged<TransectObservationModel>? onObservationTap;
  final Color lineColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineNativeZoom = isOnline
        ? 19
        : (ref.watch(
                offlineMapDownloadControllerProvider.select(
                  (state) => state.cacheStatus?.maxDownloadedZoom,
                ),
              ) ??
              ref
                  .watch(offlineMapNativeZoomProvider)
                  .when(
                    data: (zoom) => zoom,
                    loading: () => 13,
                    error: (_, _) => 13,
                  ));
    final initialCenter =
        currentLocation ??
        (points.isNotEmpty
            ? LatLng(points.first.latitude, points.first.longitude)
            : const LatLng(12.8797, 121.774));
    final displaySegments = segments?.isNotEmpty == true ? segments! : [points];
    final straightLines = displaySegments
        .where((segment) => segment.length >= 2)
        .map(
          (segment) => [
            LatLng(segment.first.latitude, segment.first.longitude),
            LatLng(segment.last.latitude, segment.last.longitude),
          ],
        )
        .toList();
    final markers = <Marker>[
      if (currentLocation != null)
        Marker(
          point: currentLocation!,
          width: 42,
          height: 42,
          child: const _MapMarker(
            color: Color(0xFF2472B8),
            icon: Icons.my_location_rounded,
            label: 'Current location',
          ),
        ),
      for (final line in straightLines) ...[
        Marker(
          point: LatLng(
            (line.first.latitude + line.last.latitude) / 2,
            (line.first.longitude + line.last.longitude) / 2,
          ),
          width: 52,
          height: 42,
          child: _MapMarker(
            color: lineColor,
            labelText: transectLabel.startsWith('T')
                ? transectLabel.substring(1)
                : transectLabel,
            label: '$transectLabel line',
          ),
        ),
        Marker(
          point: line.first,
          width: 42,
          height: 42,
          child: _MapMarker(
            color: AppColors.primaryGreen,
            labelText: 'S',
            label: '$transectLabel start',
          ),
        ),
        Marker(
          point: line.last,
          width: 42,
          height: 42,
          child: _MapMarker(
            color: AppColors.dangerRed,
            labelText: 'E',
            label: '$transectLabel end',
          ),
        ),
      ],
      ...observations
          .where((observation) => observation.hasCoordinates)
          .map(
            (observation) => Marker(
              point: LatLng(observation.latitude!, observation.longitude!),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: onObservationTap == null
                    ? null
                    : () => onObservationTap!(observation),
                child: _MapMarker(
                  color: AppColors.warningOrange,
                  icon: Icons.eco_rounded,
                  label: observation.scientificName.isEmpty
                      ? observation.recordCode
                      : observation.scientificName,
                ),
              ),
            ),
          ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: points.isEmpty && currentLocation == null ? 6 : 16,
              minZoom: 4,
              maxZoom: 25,
              onTap: onMapTap == null ? null : (_, point) => onMapTap!(point),
            ),
            children: [
              if (layer == TransectMapLayer.satellite)
                TileLayer(
                  urlTemplate: OfflineMapCacheService.tileUrlTemplate,
                  userAgentPackageName:
                      OfflineMapCacheService.userAgentPackageName,
                  maxZoom: 25,
                  maxNativeZoom: isOnline ? 20 : offlineNativeZoom ?? 13,
                  tileProvider: ref
                      .read(offlineMapCacheServiceProvider)
                      .tileProvider(isOnline: isOnline),
                )
              else if (isOnline)
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      OfflineMapCacheService.userAgentPackageName,
                  maxZoom: 25,
                  maxNativeZoom: 19,
                ),
              if (layer == TransectMapLayer.satellite && isOnline)
                TileLayer(
                  urlTemplate: OfflineMapCacheService.labelTileUrlTemplate,
                  userAgentPackageName:
                      OfflineMapCacheService.userAgentPackageName,
                  maxZoom: 25,
                  maxNativeZoom: 19,
                ),
              if (straightLines.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (final line in straightLines) ...[
                      Polyline(
                        points: line,
                        color: Colors.white,
                        strokeWidth: 12,
                      ),
                      Polyline(points: line, color: lineColor, strokeWidth: 8),
                    ],
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.add_rounded,
                  label: 'Zoom in',
                  onPressed: () => _changeZoom(0.5),
                ),
                const SizedBox(height: 8),
                _ZoomButton(
                  icon: Icons.remove_rounded,
                  label: 'Zoom out',
                  onPressed: () => _changeZoom(-0.5),
                ),
              ],
            ),
          ),
          if (!isOnline && layer == TransectMapLayer.street)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Color(0xDDF3FAF5),
                  child: Center(child: _OfflineStreetMessage()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _changeZoom(double difference) {
    try {
      final camera = mapController.camera;
      mapController.move(
        camera.center,
        (camera.zoom + difference).clamp(4.0, 25.0),
      );
    } catch (_) {
      // Ignore taps before the map has attached its controller.
    }
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    elevation: 3,
    child: IconButton(
      tooltip: label,
      icon: Icon(icon, color: AppColors.primaryDarkGreen),
      onPressed: onPressed,
    ),
  );
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.color,
    required this.label,
    this.icon,
    this.labelText,
  });

  final Color color;
  final String label;
  final IconData? icon;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: labelText != null && labelText!.length > 1 ? 42 : 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33003C3A),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: labelText != null
              ? Text(
                  labelText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 17),
        ),
      ),
    );
  }
}

class _OfflineStreetMessage extends StatelessWidget {
  const _OfflineStreetMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: AppColors.warningOrange),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Street map needs internet. Use Satellite for cached field tiles.',
            ),
          ),
        ],
      ),
    );
  }
}
