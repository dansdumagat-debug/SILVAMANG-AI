import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../map/data/services/offline_map_cache_service.dart';
import '../../data/models/transect_observation_model.dart';
import '../../data/models/transect_point_model.dart';

enum TransectMapLayer { satellite, street }

class TransectFieldMap extends ConsumerWidget {
  const TransectFieldMap({
    super.key,
    required this.mapController,
    required this.points,
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
  final List<TransectObservationModel> observations;
  final LatLng? currentLocation;
  final bool isOnline;
  final TransectMapLayer layer;
  final ValueChanged<LatLng>? onMapTap;
  final ValueChanged<TransectObservationModel>? onObservationTap;
  final Color lineColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialCenter =
        currentLocation ??
        (points.isNotEmpty
            ? LatLng(points.first.latitude, points.first.longitude)
            : const LatLng(12.8797, 121.774));
    final path = points
        .map((point) => LatLng(point.latitude, point.longitude))
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
      ..._intermediateMarkers(path),
      if (path.isNotEmpty)
        Marker(
          point: path.first,
          width: 42,
          height: 42,
          child: const _MapMarker(
            color: AppColors.primaryGreen,
            labelText: 'S',
            label: 'Transect start',
          ),
        ),
      if (path.length >= 2)
        Marker(
          point: path.last,
          width: 42,
          height: 42,
          child: const _MapMarker(
            color: AppColors.dangerRed,
            labelText: 'E',
            label: 'Transect end',
          ),
        ),
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
              maxZoom: 22,
              onTap: onMapTap == null ? null : (_, point) => onMapTap!(point),
            ),
            children: [
              if (layer == TransectMapLayer.satellite)
                TileLayer(
                  urlTemplate: OfflineMapCacheService.tileUrlTemplate,
                  userAgentPackageName:
                      OfflineMapCacheService.userAgentPackageName,
                  maxZoom: 22,
                  maxNativeZoom: 19,
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
                  maxZoom: 19,
                ),
              if (layer == TransectMapLayer.satellite && isOnline)
                TileLayer(
                  urlTemplate: OfflineMapCacheService.labelTileUrlTemplate,
                  userAgentPackageName:
                      OfflineMapCacheService.userAgentPackageName,
                  maxZoom: 22,
                  maxNativeZoom: 19,
                ),
              if (path.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(points: path, color: Colors.white, strokeWidth: 8),
                    Polyline(points: path, color: lineColor, strokeWidth: 5),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
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

  List<Marker> _intermediateMarkers(List<LatLng> path) {
    if (path.length <= 2) {
      return const [];
    }
    final step = path.length > 200 ? (path.length / 200).ceil() : 1;
    return [
      for (var index = 1; index < path.length - 1; index += step)
        Marker(
          point: path[index],
          width: 10,
          height: 10,
          child: Container(
            decoration: BoxDecoration(
              color: lineColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
    ];
  }
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
        width: 34,
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
