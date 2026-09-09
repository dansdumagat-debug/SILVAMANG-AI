import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/local_image_preview.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../../shared/models/scan_record_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../location/data/services/barangay_resolver_service.dart';
import '../../../records/data/repositories/scan_record_repository.dart';
import '../../data/models/map_scan_record.dart';
import '../../data/repositories/local_map_scan_repository.dart';
import '../../data/services/offline_map_cache_service.dart';

class MapRecordsPage extends ConsumerStatefulWidget {
  const MapRecordsPage({super.key});

  @override
  ConsumerState<MapRecordsPage> createState() => _MapRecordsPageState();
}

class _MapRecordsPageState extends ConsumerState<MapRecordsPage> {
  static const double _bottomNavigationReserve = 120;
  static const String _allSpeciesFilter = 'All species';

  final MapController _mapController = MapController();
  final LocationService _locationService = const LocationService();
  final ConnectivityService _connectivityService = const ConnectivityService();
  Future<_MapRecordsState>? _future;
  MapScanRecord? _selectedRecord;
  String _selectedSpecies = _allSpeciesFilter;

  @override
  void initState() {
    super.initState();
    _future = _loadMapState();
  }

  Future<_MapRecordsState> _loadMapState() async {
    final authState = ref.read(authControllerProvider);
    final localRecords = await ref
        .read(localMapScanRepositoryProvider)
        .getRecordsForUser(
          userId: authState.user?.id,
          userEmail: authState.user?.email,
          includeGuestRecords: true,
          includeLegacyRecords: true,
        );
    final isOnline = await _connectivityService.hasNetworkConnection();
    var records = localRecords;
    String? recordLoadMessage;

    if (isOnline && authState.isAuthenticated) {
      try {
        final serverRecords = await ref
            .read(scanRecordRepositoryProvider)
            .getScanRecords();
        records = _mergeRecords(
          localRecords: localRecords,
          serverRecords: _serverRecordsToMapRecords(
            serverRecords,
            authState.user?.email,
          ),
        );
      } catch (_) {
        recordLoadMessage = 'Showing local scan pins only.';
      }
    }

    final resolvedRecords = await _recordsWithResolvedBarangay(records);
    final cacheService = ref.read(offlineMapCacheServiceProvider);
    final cacheStatus = await cacheService.status();
    final locationResult = await _locationService.getCurrentLocationResult(
      timeout: const Duration(seconds: 8),
    );

    return _MapRecordsState(
      records: resolvedRecords
          .where((record) => record.hasCoordinates)
          .toList(),
      currentLocation: locationResult.location,
      isOnline: isOnline,
      cacheStatus: cacheStatus,
      locationMessage: _joinMessages([
        if (locationResult.location == null)
          locationResult.errorMessage ?? 'Current location unavailable.',
        recordLoadMessage,
      ]),
    );
  }

  void _refresh() {
    setState(() {
      _selectedRecord = null;
      _selectedSpecies = _allSpeciesFilter;
      _future = _loadMapState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('Mangrove Map'),
        actions: [
          IconButton(
            tooltip: 'Manage Offline Maps',
            onPressed: () => context.pushNamed(RouteNames.offlineMapManager),
            icon: const Icon(Icons.download_for_offline_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_MapRecordsState>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MapMessageState(
              icon: Icons.error_outline_rounded,
              title: 'Map records unavailable',
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final state = snapshot.data ?? const _MapRecordsState(records: []);
          final speciesChoices = _speciesChoices(state.records);
          final visibleRecords = _recordsForSelectedSpecies(state.records);

          final initialCenter = _initialCenter(state, visibleRecords);
          final markers = <Marker>[
            if (state.currentLocation != null)
              Marker(
                point: LatLng(
                  state.currentLocation!.latitude,
                  state.currentLocation!.longitude,
                ),
                width: 46,
                height: 46,
                child: _MapPin(
                  color: Colors.blue.shade600,
                  icon: Icons.my_location_rounded,
                ),
              ),
            ...visibleRecords.map(
              (record) => Marker(
                point: LatLng(record.latitude!, record.longitude!),
                width: 48,
                height: 48,
                child: GestureDetector(
                  onTap: () => _selectRecord(record),
                  child: _MapPin(
                    color: _markerColor(record),
                    icon: Icons.eco_rounded,
                    isSelected: _selectedRecord?.localId == record.localId,
                  ),
                ),
              ),
            ),
          ];

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: visibleRecords.isEmpty
                      ? state.currentLocation == null
                            ? 6
                            : 15
                      : 13,
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
                    tileProvider: ref
                        .read(offlineMapCacheServiceProvider)
                        .tileProvider(isOnline: state.isOnline),
                  ),
                  if (state.isOnline)
                    TileLayer(
                      urlTemplate: OfflineMapCacheService.labelTileUrlTemplate,
                      userAgentPackageName:
                          OfflineMapCacheService.userAgentPackageName,
                      maxZoom: 22,
                      maxNativeZoom: 19,
                    ),
                  MarkerLayer(markers: markers),
                ],
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                child: _MapTopBar(
                  recordCount: visibleRecords.length,
                  totalRecordCount: state.records.length,
                  speciesChoices: speciesChoices,
                  selectedSpecies: _selectedSpecies,
                  onSpeciesChanged: (species) =>
                      _selectSpecies(species, state.records),
                  locationMessage:
                      state.locationMessage ?? state.offlineMapMessage,
                ),
              ),
              if (_selectedRecord != null)
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: _bottomNavigationReserve + AppSpacing.lg,
                  child: _RecordDetailsCard(
                    record: _selectedRecord!,
                    onClose: () => setState(() => _selectedRecord = null),
                    onOpenMaps: () => _openInMaps(
                      context,
                      _selectedRecord!.latitude!,
                      _selectedRecord!.longitude!,
                    ),
                    onViewRecord: _selectedRecord!.serverId == null
                        ? null
                        : () => context.pushNamed(
                            RouteNames.recordDetail,
                            pathParameters: {
                              'id': _selectedRecord!.serverId.toString(),
                            },
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<MapScanRecord> _serverRecordsToMapRecords(
    List<ScanRecordModel> scanRecords,
    String? userEmail,
  ) {
    final records = <MapScanRecord>[];

    for (final scanRecord in scanRecords) {
      final latitude =
          scanRecord.latitude ?? scanRecord.locationValidation?.latitude;
      final longitude =
          scanRecord.longitude ?? scanRecord.locationValidation?.longitude;
      final capturedAt = scanRecord.capturedAt ?? scanRecord.createdAt;
      final serverId = scanRecord.id.trim();

      records.add(
        MapScanRecord(
          localId: serverId.isEmpty
              ? 'server_scan_${capturedAt.microsecondsSinceEpoch}_${records.length}'
              : 'server_$serverId',
          serverId: serverId.isEmpty ? null : serverId,
          userId: scanRecord.userId,
          userEmail: userEmail,
          speciesName: scanRecord.topScientificName,
          commonName: scanRecord.topCommonName,
          confidence: scanRecord.confidence,
          imagePath: _serverRecordImagePath(scanRecord),
          latitude: latitude,
          longitude: longitude,
          accuracy: scanRecord.accuracy,
          barangay: scanRecord.barangay,
          manualBarangay: scanRecord.manualBarangay,
          locationLookupStatus:
              scanRecord.locationLookupStatus ??
              scanRecord.locationValidation?.message,
          locationSource: 'server_scan_record',
          heightM: scanRecord.heightM ?? scanRecord.measurement?.heightM,
          canopyWidthM:
              scanRecord.canopyWidthM ?? scanRecord.measurement?.canopyWidthM,
          notes: scanRecord.notes,
          syncStatus: MapScanRecord.synced,
          createdAt: capturedAt,
          updatedAt: scanRecord.updatedAt ?? scanRecord.createdAt,
        ),
      );
    }

    return records;
  }

  String? _serverRecordImagePath(ScanRecordModel scanRecord) {
    for (final image in scanRecord.images) {
      final localUri = image.localUri?.trim();
      if (localUri != null && localUri.isNotEmpty) {
        return localUri;
      }

      final imagePath = image.imagePath.trim();
      if (imagePath.isNotEmpty) {
        return imagePath;
      }

      final imageUrl = image.imageUrl.trim();
      if (imageUrl.isNotEmpty) {
        return imageUrl;
      }
    }

    return null;
  }

  List<MapScanRecord> _mergeRecords({
    required List<MapScanRecord> localRecords,
    required List<MapScanRecord> serverRecords,
  }) {
    final mergedRecords = <String, MapScanRecord>{};

    for (final record in serverRecords) {
      mergedRecords[_dedupeKey(record)] = record;
    }

    for (final record in localRecords) {
      final key = _dedupeKey(record);
      final existing = mergedRecords[key];
      mergedRecords[key] = existing == null
          ? record
          : _mergeRecord(existing: existing, preferred: record);
    }

    return mergedRecords.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  MapScanRecord _mergeRecord({
    required MapScanRecord existing,
    required MapScanRecord preferred,
  }) {
    return MapScanRecord(
      localId: preferred.localId,
      serverId: preferred.serverId ?? existing.serverId,
      userId: preferred.userId ?? existing.userId,
      userEmail: preferred.userEmail ?? existing.userEmail,
      speciesName: _pickText(preferred.speciesName, existing.speciesName) ?? '',
      commonName: _pickText(preferred.commonName, existing.commonName),
      confidence: preferred.confidence ?? existing.confidence,
      imagePath: _pickText(preferred.imagePath, existing.imagePath),
      latitude: preferred.latitude ?? existing.latitude,
      longitude: preferred.longitude ?? existing.longitude,
      accuracy: preferred.accuracy ?? existing.accuracy,
      barangay: _pickText(preferred.barangay, existing.barangay),
      manualBarangay: _pickText(
        preferred.manualBarangay,
        existing.manualBarangay,
      ),
      locationLookupStatus: _pickText(
        preferred.locationLookupStatus,
        existing.locationLookupStatus,
      ),
      locationSource: _pickText(
        preferred.locationSource,
        existing.locationSource,
      ),
      heightM: preferred.heightM ?? existing.heightM,
      canopyWidthM: preferred.canopyWidthM ?? existing.canopyWidthM,
      fieldDistanceM: preferred.fieldDistanceM ?? existing.fieldDistanceM,
      notes: _pickText(preferred.notes, existing.notes),
      syncStatus: preferred.syncStatus == MapScanRecord.synced
          ? preferred.syncStatus
          : existing.syncStatus,
      createdAt: preferred.createdAt,
      updatedAt: preferred.updatedAt.isAfter(existing.updatedAt)
          ? preferred.updatedAt
          : existing.updatedAt,
    );
  }

  String _dedupeKey(MapScanRecord record) {
    final serverId = record.serverId?.trim();
    if (serverId != null && serverId.isNotEmpty) {
      return 'server:$serverId';
    }

    return 'local:${record.localId}';
  }

  String? _pickText(String? preferred, String? fallback) {
    final cleanPreferred = preferred?.trim();
    if (cleanPreferred != null && cleanPreferred.isNotEmpty) {
      return cleanPreferred;
    }

    final cleanFallback = fallback?.trim();
    if (cleanFallback != null && cleanFallback.isNotEmpty) {
      return cleanFallback;
    }

    return null;
  }

  List<String> _speciesChoices(List<MapScanRecord> records) {
    final names = <String>{};
    for (final record in records) {
      final species = _speciesFilterLabel(record);
      if (species.isNotEmpty) {
        names.add(species);
      }
    }

    final sortedNames = names.toList()..sort();
    return <String>[_allSpeciesFilter, ...sortedNames];
  }

  Future<List<MapScanRecord>> _recordsWithResolvedBarangay(
    List<MapScanRecord> records,
  ) async {
    final resolver = ref.read(barangayResolverServiceProvider);
    final repository = ref.read(localMapScanRepositoryProvider);
    final resolvedRecords = <MapScanRecord>[];

    for (final record in records) {
      var resolvedRecord = record;
      if (record.hasCoordinates && !_hasText(record.barangay)) {
        final resolution = await resolver.resolve(
          latitude: record.latitude!,
          longitude: record.longitude!,
          accuracy: record.accuracy,
        );
        if (_hasText(resolution.barangay)) {
          resolvedRecord = record.copyWith(
            barangay: resolution.barangay,
            locationLookupStatus: resolution.message ?? resolution.status,
            locationSource: resolution.source,
            updatedAt: DateTime.now(),
          );
          await repository.saveLocalRecord(resolvedRecord);
        }
      }
      resolvedRecords.add(resolvedRecord);
    }

    return resolvedRecords;
  }

  List<MapScanRecord> _recordsForSelectedSpecies(List<MapScanRecord> records) {
    if (_selectedSpecies == _allSpeciesFilter) {
      return records;
    }

    return records
        .where((record) => _speciesFilterLabel(record) == _selectedSpecies)
        .toList();
  }

  void _selectSpecies(String species, List<MapScanRecord> records) {
    final nextRecords = species == _allSpeciesFilter
        ? records
        : records
              .where((record) => _speciesFilterLabel(record) == species)
              .toList();

    setState(() {
      _selectedSpecies = species;
      _selectedRecord = nextRecords.isEmpty ? null : nextRecords.first;
    });

    if (nextRecords.isNotEmpty) {
      _moveToRecord(
        nextRecords.first,
        zoom: species == _allSpeciesFilter ? 13 : 15,
      );
    }
  }

  void _selectRecord(MapScanRecord record) {
    setState(() => _selectedRecord = record);
    _moveToRecord(record, zoom: 16);
  }

  void _moveToRecord(MapScanRecord record, {required double zoom}) {
    if (!record.hasCoordinates) {
      return;
    }

    _mapController.move(LatLng(record.latitude!, record.longitude!), zoom);
  }

  String _speciesFilterLabel(MapScanRecord record) {
    final scientificName = record.speciesName.trim().replaceAll('_', ' ');
    if (scientificName.isNotEmpty) {
      return scientificName;
    }

    return record.commonName?.trim() ?? '';
  }

  LatLng _initialCenter(
    _MapRecordsState state,
    List<MapScanRecord> visibleRecords,
  ) {
    if (state.currentLocation != null) {
      return LatLng(
        state.currentLocation!.latitude,
        state.currentLocation!.longitude,
      );
    }

    if (visibleRecords.isNotEmpty) {
      final record = visibleRecords.first;
      return LatLng(record.latitude!, record.longitude!);
    }

    return const LatLng(12.8797, 121.774);
  }

  Color _markerColor(MapScanRecord record) {
    if (_selectedRecord?.localId == record.localId) {
      return Colors.blue.shade600;
    }

    switch (record.syncStatus) {
      case MapScanRecord.synced:
        return AppColors.primaryGreen;
      case MapScanRecord.pending:
      case MapScanRecord.localOnly:
        return AppColors.warningOrange;
      case MapScanRecord.failed:
        return AppColors.dangerRed;
      default:
        return Colors.grey.shade700;
    }
  }
}

bool _hasText(String? value) => value?.trim().isNotEmpty == true;

String? _joinMessages(List<String?> messages) {
  final cleanMessages = messages
      .whereType<String>()
      .map((message) => message.trim())
      .where((message) => message.isNotEmpty)
      .toList();

  return cleanMessages.isEmpty ? null : cleanMessages.join(' ');
}

String _locationSourceLabel(String? source) {
  final normalized = source?.trim().toLowerCase();
  return switch (normalized) {
    'online_location' => 'Online location',
    'offline_geojson' => 'Offline barangay boundary',
    'offline_downloaded_boundary' => 'Offline downloaded boundary',
    'gps_low_accuracy' => 'GPS accuracy too low',
    'manual_barangay' => 'Manual barangay',
    'location_unavailable' => 'Location unavailable',
    'offline_geojson_missing' => 'Boundary file missing',
    'offline_geojson_empty' => 'Boundary data unavailable',
    'offline_geojson_invalid' => 'Boundary data invalid',
    'offline_geojson_error' => 'Boundary lookup error',
    'server_scan_record' => 'Saved scan record',
    'unavailable' || '' || null => 'Not available',
    _ => source!.replaceAll('_', ' '),
  };
}

class _MapRecordsState {
  const _MapRecordsState({
    required this.records,
    this.currentLocation,
    this.isOnline = true,
    this.cacheStatus,
    this.locationMessage,
  });

  final List<MapScanRecord> records;
  final DeviceLocation? currentLocation;
  final bool isOnline;
  final OfflineMapCacheStatus? cacheStatus;
  final String? locationMessage;

  String? get offlineMapMessage {
    if (isOnline) {
      return cacheStatus?.hasCachedTiles == true
          ? 'Online. Map tiles are cached as you browse.'
          : 'Online. Download an area before field work.';
    }

    if (cacheStatus?.hasCachedTiles == true) {
      return 'Offline. Showing cached map tiles where available.';
    }

    return 'Offline map not downloaded for this area.';
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({
    required this.recordCount,
    required this.totalRecordCount,
    required this.speciesChoices,
    required this.selectedSpecies,
    required this.onSpeciesChanged,
    this.locationMessage,
  });

  final int recordCount;
  final int totalRecordCount;
  final List<String> speciesChoices;
  final String selectedSpecies;
  final ValueChanged<String> onSpeciesChanged;
  final String? locationMessage;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, color: AppColors.primaryDarkGreen),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Mangrove Map', style: AppTextStyles.titleMedium),
              ),
              SilvamangBadge(
                label: recordCount == totalRecordCount
                    ? '$recordCount pins'
                    : '$recordCount of $totalRecordCount pins',
                type: SilvamangBadgeType.success,
              ),
            ],
          ),
          if (speciesChoices.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Choose species to show', style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final species in speciesChoices) ...[
                    _SpeciesChoiceChip(
                      label: species,
                      isSelected: species == selectedSpecies,
                      onSelected: () => onSpeciesChanged(species),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
            ),
          ],
          if (locationMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(locationMessage!, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _SpeciesChoiceChip extends StatelessWidget {
  const _SpeciesChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      avatar: Icon(
        label == _MapRecordsPageState._allSpeciesFilter
            ? Icons.public_rounded
            : Icons.eco_rounded,
        size: 16,
        color: isSelected ? AppColors.white : AppColors.primaryDarkGreen,
      ),
      labelStyle: AppTextStyles.bodySmall.copyWith(
        color: isSelected ? AppColors.white : AppColors.primaryDarkGreen,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primaryDarkGreen,
      backgroundColor: AppColors.softGreen,
      side: BorderSide(
        color: isSelected ? AppColors.primaryDarkGreen : AppColors.softGreen,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.color,
    required this.icon,
    this.isSelected = false,
  });

  final Color color;
  final IconData icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.14 : 1,
      duration: const Duration(milliseconds: 180),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.white, size: 23),
      ),
    );
  }
}

class _RecordDetailsCard extends StatelessWidget {
  const _RecordDetailsCard({
    required this.record,
    required this.onClose,
    required this.onOpenMaps,
    this.onViewRecord,
  });

  final MapScanRecord record;
  final VoidCallback onClose;
  final VoidCallback onOpenMaps;
  final VoidCallback? onViewRecord;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumbnail(imagePath: record.imagePath),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        record.speciesName.isEmpty
                            ? 'Unknown species'
                            : record.speciesName,
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                    SilvamangBadge(
                      label: _syncLabel(record.syncStatus),
                      type: _syncBadgeType(record.syncStatus),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                if (record.commonName?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(record.commonName!, style: AppTextStyles.bodySmall),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (record.confidence != null)
                      _InfoChip(
                        icon: Icons.verified_rounded,
                        text:
                            '${record.confidence!.toStringAsFixed(1)}% confidence',
                      ),
                    _InfoChip(
                      icon: Icons.location_pin,
                      text:
                          record.barangay ??
                          record.manualBarangay ??
                          'Barangay not available',
                    ),
                    if (_hasText(record.locationSource))
                      _InfoChip(
                        icon: Icons.layers_rounded,
                        text: _locationSourceLabel(record.locationSource),
                      ),
                    _InfoChip(
                      icon: Icons.calendar_today_rounded,
                      text: DateFormat('MMM d, yyyy').format(record.createdAt),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${record.latitude?.toStringAsFixed(6) ?? '-'}, '
                  '${record.longitude?.toStringAsFixed(6) ?? '-'}',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onOpenMaps,
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Open in Maps'),
                    ),
                    if (onViewRecord != null)
                      FilledButton.icon(
                        onPressed: onViewRecord,
                        icon: const Icon(Icons.description_rounded),
                        label: const Text('View Record'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _syncLabel(String status) {
    switch (status) {
      case MapScanRecord.synced:
        return 'Synced';
      case MapScanRecord.pending:
        return 'Pending sync';
      case MapScanRecord.failed:
        return 'Failed';
      case MapScanRecord.localOnly:
        return 'Local only';
      default:
        return status;
    }
  }

  SilvamangBadgeType _syncBadgeType(String status) {
    switch (status) {
      case MapScanRecord.synced:
        return SilvamangBadgeType.success;
      case MapScanRecord.failed:
        return SilvamangBadgeType.warning;
      default:
        return SilvamangBadgeType.info;
    }
  }
}

Future<void> _openInMaps(
  BuildContext context,
  double latitude,
  double longitude,
) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  );
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open maps.')));
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return LocalImagePreview(
      imagePath: imagePath,
      width: 72,
      height: 72,
      borderRadius: 14,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryDarkGreen),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMessageState extends StatelessWidget {
  const _MapMessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.screenPadding),
        child: SilvamangCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: AppColors.primaryDarkGreen),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
