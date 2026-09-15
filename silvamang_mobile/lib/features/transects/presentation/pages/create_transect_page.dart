import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../map/data/repositories/local_map_scan_repository.dart';
import '../../../records/presentation/controllers/records_controller.dart';
import '../../data/models/transect_observation_model.dart';
import '../../data/models/transect_point_model.dart';
import '../../data/models/transect_record_model.dart';
import '../../data/services/transect_geometry_service.dart';
import '../controllers/transects_controller.dart';
import '../widgets/transect_field_map.dart';

class CreateTransectPage extends ConsumerStatefulWidget {
  const CreateTransectPage({super.key});

  @override
  ConsumerState<CreateTransectPage> createState() => _CreateTransectPageState();
}

class _CreateTransectPageState extends ConsumerState<CreateTransectPage> {
  static const _maximumGpsAccuracyM = 50.0;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mapController = MapController();
  final _locationService = const LocationService();
  final _connectivityService = const ConnectivityService();
  final _geometryService = const TransectGeometryService();

  final List<TransectPointModel> _points = [];
  final Map<String, TransectObservationModel> _selectedObservations = {};
  List<TransectObservationModel> _availableObservations = const [];
  StreamSubscription<DeviceLocation>? _locationSubscription;
  DeviceLocation? _currentLocation;
  DateTime _recordedAt = DateTime.now();
  String _mode = TransectRecordModel.modeGpsTracking;
  TransectMapLayer _mapLayer = TransectMapLayer.satellite;
  bool _isOnline = false;
  bool _isInitializing = true;
  bool _isLoadingObservations = false;
  bool _isTracking = false;
  int _ignoredGpsFixes = 0;
  String? _fieldMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final isOnline = await _connectivityService.hasNetworkConnection();
    final locationResult = await _locationService.getCurrentLocationResult(
      timeout: const Duration(seconds: 12),
    );
    if (!mounted) return;
    setState(() {
      _isOnline = isOnline;
      _currentLocation = locationResult.location;
      _fieldMessage = locationResult.location == null
          ? locationResult.errorMessage
          : null;
      _isInitializing = false;
    });
    unawaited(_loadObservationChoices());
  }

  Future<void> _loadObservationChoices() async {
    if (_isLoadingObservations) return;
    setState(() => _isLoadingObservations = true);

    final auth = ref.read(authControllerProvider);
    final merged = <String, TransectObservationModel>{};
    try {
      await ref.read(recordsControllerProvider.notifier).loadRecords();
      for (final record in ref.read(recordsControllerProvider).records) {
        if (auth.user?.id != null &&
            record.userId != null &&
            record.userId != auth.user!.id) {
          continue;
        }
        final observation = TransectObservationModel.fromScanRecord(record);
        if (observation.reference.isNotEmpty) {
          merged[_observationKey(observation)] = observation;
        }
      }
    } catch (_) {
      // Local observation snapshots remain available when the API cannot load.
    }

    final localRecords = await ref
        .read(localMapScanRepositoryProvider)
        .getRecordsForUser(
          userId: auth.user?.id,
          userEmail: auth.user?.email,
          includeGuestRecords: !auth.isAuthenticated,
        );
    for (final record in localRecords) {
      final observation = TransectObservationModel.fromMapRecord(record);
      merged.putIfAbsent(_observationKey(observation), () => observation);
    }

    final observations = merged.values.toList()
      ..sort(
        (a, b) => (b.capturedAt ?? DateTime(2000)).compareTo(
          a.capturedAt ?? DateTime(2000),
        ),
      );
    if (!mounted) return;
    setState(() {
      _availableObservations = observations;
      _isLoadingObservations = false;
    });
  }

  String _observationKey(TransectObservationModel observation) {
    final code = observation.recordCode.trim();
    if (code.isNotEmpty && code != 'Local observation') return 'code:$code';
    final offline = observation.offlineReference?.trim();
    if (offline != null && offline.isNotEmpty) return 'offline:$offline';
    return observation.reference;
  }

  Future<void> _startTracking() async {
    if (_isTracking) return;
    final result = await _locationService.getCurrentLocationResult(
      timeout: const Duration(seconds: 20),
    );
    final location = result.location;
    if (!mounted) return;
    if (location == null) {
      setState(() => _fieldMessage = result.errorMessage);
      return;
    }

    final point = _pointFromLocation(location);
    final acceptsInitialFix = location.accuracy <= _maximumGpsAccuracyM;
    await _locationSubscription?.cancel();
    setState(() {
      _points.clear();
      if (acceptsInitialFix) {
        _points.add(point);
      }
      _currentLocation = location;
      _isTracking = true;
      _ignoredGpsFixes = 0;
      if (acceptsInitialFix) {
        _recordedAt = location.timestamp;
      }
      _fieldMessage = !acceptsInitialFix
          ? 'Waiting for a usable GPS fix (${location.accuracy.toStringAsFixed(0)} m). Move to clearer sky while tracking continues.'
          : 'GPS transect recording active.';
    });
    _moveMap(point, zoom: 18);

    _locationSubscription = _locationService
        .watchLocations(distanceFilterMeters: 1)
        .listen(_handleLocation, onError: _handleLocationError);
  }

  void _handleLocation(DeviceLocation location) {
    if (!mounted || !_isTracking) return;
    final candidate = _pointFromLocation(location);
    final hasUsableAccuracy =
        candidate.accuracyM == null ||
        candidate.accuracyM! <= _maximumGpsAccuracyM;
    final shouldAppend =
        hasUsableAccuracy &&
        (_points.isEmpty ||
            _geometryService.shouldAppendGpsPoint(
              previous: _points.last,
              candidate: candidate,
              maximumAccuracyM: _maximumGpsAccuracyM,
            ));
    setState(() {
      _currentLocation = location;
      if (shouldAppend) {
        if (_points.isEmpty) {
          _recordedAt = location.timestamp;
        }
        _points.add(candidate);
        _fieldMessage = 'GPS point ${_points.length} recorded.';
      } else if (location.accuracy > _maximumGpsAccuracyM) {
        _ignoredGpsFixes++;
        _fieldMessage =
            'Weak GPS fix ignored (${location.accuracy.toStringAsFixed(0)} m).';
      }
    });
    if (shouldAppend) _moveMap(candidate, zoom: 18);
  }

  void _handleLocationError(Object error) {
    if (!mounted) return;
    setState(() => _fieldMessage = 'GPS tracking paused: $error');
  }

  Future<void> _endTracking() async {
    if (!_isTracking) return;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    if (!mounted) return;
    setState(() {
      _isTracking = false;
      _fieldMessage = _points.length >= 2
          ? 'Transect path complete.'
          : 'Walk farther and resume tracking to record an endpoint.';
    });
    _fitPath();
  }

  Future<void> _resumeTracking() async {
    if (_isTracking || _points.isEmpty) return;
    final allowed = await _locationService.requestLocationPermission();
    if (!allowed || !mounted) {
      setState(() => _fieldMessage = 'Location permission is required.');
      return;
    }
    setState(() {
      _isTracking = true;
      _fieldMessage = 'GPS transect recording resumed.';
    });
    _locationSubscription = _locationService
        .watchLocations(distanceFilterMeters: 1)
        .listen(_handleLocation, onError: _handleLocationError);
  }

  void _handleManualMapTap(LatLng point) {
    if (_mode != TransectRecordModel.modeManualPoints || _isTracking) return;
    final selectedPoint = TransectPointModel(
      latitude: point.latitude,
      longitude: point.longitude,
      recordedAt: DateTime.now(),
    );
    setState(() {
      if (_points.isEmpty) {
        _points.add(selectedPoint);
        _fieldMessage = 'Start point selected.';
      } else if (_points.length == 1) {
        _points.add(selectedPoint);
        _fieldMessage = 'Endpoint selected.';
      } else {
        _points[_points.length - 1] = selectedPoint;
        _fieldMessage = 'Endpoint moved.';
      }
    });
    if (_points.length >= 2) _fitPath();
  }

  void _useCurrentLocation() {
    final location = _currentLocation;
    if (location == null) {
      setState(() => _fieldMessage = 'Current GPS location is unavailable.');
      return;
    }
    _handleManualMapTap(LatLng(location.latitude, location.longitude));
  }

  Future<void> _changeMode(String mode) async {
    if (_mode == mode || _isTracking) return;
    if (_points.isNotEmpty) {
      final reset = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change transect mode?'),
          content: const Text('The current path points will be cleared.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change Mode'),
            ),
          ],
        ),
      );
      if (reset != true || !mounted) return;
    }
    setState(() {
      _mode = mode;
      _points.clear();
      _fieldMessage = null;
    });
  }

  void _resetPath() {
    if (_isTracking) return;
    setState(() {
      _points.clear();
      _ignoredGpsFixes = 0;
      _fieldMessage = 'Path cleared.';
    });
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _recordedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _recordedAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _recordedAt.hour,
        _recordedAt.minute,
      );
    });
  }

  Future<void> _showObservationPicker() async {
    if (_isLoadingObservations) return;
    final workingSelection = <String>{..._selectedObservations.keys};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Attach Observations',
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reload observations',
                        onPressed: () async {
                          Navigator.pop(context);
                          await _loadObservationChoices();
                          if (mounted) await _showObservationPicker();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _availableObservations.isEmpty
                      ? const Center(
                          child: Text('No scan observations available.'),
                        )
                      : ListView.builder(
                          itemCount: _availableObservations.length,
                          itemBuilder: (context, index) {
                            final observation = _availableObservations[index];
                            final key = _observationKey(observation);
                            return CheckboxListTile(
                              value: workingSelection.contains(key),
                              onChanged: (selected) {
                                setModalState(() {
                                  if (selected == true) {
                                    workingSelection.add(key);
                                  } else {
                                    workingSelection.remove(key);
                                  }
                                });
                              },
                              secondary: Icon(
                                observation.hasCoordinates
                                    ? Icons.location_on_rounded
                                    : Icons.eco_rounded,
                                color: observation.isLocalOnly
                                    ? AppColors.warningOrange
                                    : AppColors.primaryGreen,
                              ),
                              title: Text(
                                observation.scientificName.isEmpty
                                    ? 'Unidentified mangrove'
                                    : observation.scientificName,
                              ),
                              subtitle: Text(
                                '${observation.recordCode}  ${_shortDate(observation.capturedAt)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SilvamangButton(
                    text: 'Attach ${workingSelection.length} Observation(s)',
                    icon: Icons.add_location_alt_rounded,
                    onPressed: () {
                      setState(() {
                        _selectedObservations.clear();
                        for (final observation in _availableObservations) {
                          final key = _observationKey(observation);
                          if (workingSelection.contains(key)) {
                            _selectedObservations[key] = observation;
                          }
                        }
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveTransect() async {
    if (_isTracking) {
      setState(() => _fieldMessage = 'End GPS tracking before saving.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_points.length < 2) {
      setState(
        () => _fieldMessage = 'A start point and endpoint are required.',
      );
      return;
    }

    final auth = ref.read(authControllerProvider);
    final summary = _geometryService.summarize(_points);
    final now = DateTime.now();
    final record = TransectRecordModel(
      localId: 'transect_${const Uuid().v4()}',
      ownerUserId: auth.user?.id,
      ownerUserEmail: auth.user?.email,
      researcherName: auth.user?.name,
      transectName: _nameController.text.trim(),
      locationName: _emptyAsNull(_locationController.text),
      description: _emptyAsNull(_descriptionController.text),
      mode: _mode,
      status: TransectRecordModel.statusCompleted,
      points: List.unmodifiable(_points),
      observations: List.unmodifiable(_selectedObservations.values),
      totalDistanceM: summary.distanceM,
      bearingDegrees: summary.bearingDegrees,
      gpsAccuracyM: summary.averageAccuracyM,
      recordedAt: _recordedAt,
      createdAt: now,
      updatedAt: now,
      syncStatus: TransectRecordModel.syncPending,
    );
    final saved = await ref
        .read(transectsControllerProvider.notifier)
        .save(record);
    if (!mounted || saved == null) return;
    context.pushReplacementNamed(
      RouteNames.transectDetail,
      pathParameters: {'id': saved.localId},
    );
  }

  TransectPointModel _pointFromLocation(DeviceLocation location) {
    return TransectPointModel(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracyM: location.accuracy,
      altitudeM: location.altitude,
      recordedAt: location.timestamp,
    );
  }

  void _moveMap(TransectPointModel point, {required double zoom}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.move(LatLng(point.latitude, point.longitude), zoom);
      } catch (_) {
        // The map may still be mounting during the first GPS fix.
      }
    });
  }

  void _fitPath() {
    if (_points.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: _points
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList(),
            padding: const EdgeInsets.all(52),
            maxZoom: 19,
          ),
        );
      } catch (_) {
        // Preserve the captured path even if the map is not attached yet.
      }
    });
  }

  String? _emptyAsNull(String value) {
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  String _shortDate(DateTime? date) {
    return date == null ? '' : DateFormat('MMM d, y').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final transectState = ref.watch(transectsControllerProvider);
    final summary = _geometryService.summarize(_points);
    final currentPoint = _currentLocation == null
        ? null
        : LatLng(_currentLocation!.latitude, _currentLocation!.longitude);

    return PopScope(
      canPop: !_isTracking,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isTracking) {
          setState(() => _fieldMessage = 'End GPS tracking before leaving.');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.mintBackground,
        appBar: AppBar(
          leading: const SilvamangBackButton(),
          title: const Text('Create Transect'),
          actions: [
            IconButton(
              tooltip: 'Reset path',
              onPressed: _points.isEmpty || _isTracking ? null : _resetPath,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
          ],
        ),
        body: _isInitializing
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.screenPadding,
                    AppConstants.screenPadding,
                    AppConstants.screenPadding,
                    124,
                  ),
                  children: [
                    _ConnectionBanner(
                      isOnline: _isOnline,
                      isTracking: _isTracking,
                      accuracyM: _currentLocation?.accuracy,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SilvamangCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Field Record',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Transect name or ID',
                              prefixIcon: Icon(Icons.route_rounded),
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Transect name is required.'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _locationController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Location name',
                              prefixIcon: Icon(Icons.place_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Field notes or description',
                              prefixIcon: Icon(Icons.notes_rounded),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_today_rounded),
                            title: const Text('Date recorded'),
                            subtitle: Text(
                              DateFormat('MMMM d, y').format(_recordedAt),
                            ),
                            trailing: IconButton(
                              tooltip: 'Choose date',
                              onPressed: _selectDate,
                              icon: const Icon(Icons.edit_calendar_rounded),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_rounded),
                            title: const Text('Researcher'),
                            subtitle: Text(
                              auth.user?.name ?? 'Current mobile user',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SilvamangCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Survey Path',
                                  style: AppTextStyles.titleMedium,
                                ),
                              ),
                              SegmentedButton<TransectMapLayer>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: TransectMapLayer.satellite,
                                    icon: Icon(Icons.satellite_alt_rounded),
                                    tooltip: 'Satellite map',
                                  ),
                                  ButtonSegment(
                                    value: TransectMapLayer.street,
                                    icon: Icon(Icons.map_rounded),
                                    tooltip: 'Street map',
                                  ),
                                ],
                                selected: {_mapLayer},
                                onSelectionChanged: (selection) {
                                  setState(() => _mapLayer = selection.first);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            height: 430,
                            child: TransectFieldMap(
                              mapController: _mapController,
                              points: _points,
                              observations: _selectedObservations.values
                                  .toList(),
                              currentLocation: currentPoint,
                              isOnline: _isOnline,
                              layer: _mapLayer,
                              onMapTap:
                                  _mode == TransectRecordModel.modeManualPoints
                                  ? _handleManualMapTap
                                  : null,
                              lineColor:
                                  _mode == TransectRecordModel.modeGpsTracking
                                  ? AppColors.primaryGreen
                                  : const Color(0xFF2472B8),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: TransectRecordModel.modeGpsTracking,
                                label: Text('GPS Track'),
                                icon: Icon(Icons.gps_fixed_rounded),
                              ),
                              ButtonSegment(
                                value: TransectRecordModel.modeManualPoints,
                                label: Text('Manual'),
                                icon: Icon(Icons.touch_app_rounded),
                              ),
                            ],
                            selected: {_mode},
                            onSelectionChanged: _isTracking
                                ? null
                                : (selection) => _changeMode(selection.first),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (_mode == TransectRecordModel.modeGpsTracking)
                            _GpsControls(
                              isTracking: _isTracking,
                              hasPath: _points.isNotEmpty,
                              onStart: _startTracking,
                              onEnd: _endTracking,
                              onResume: _resumeTracking,
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: SilvamangButton(
                                    text: _points.isEmpty
                                        ? 'Set Start at GPS'
                                        : 'Set Endpoint at GPS',
                                    icon: Icons.my_location_rounded,
                                    type: SilvamangButtonType.outline,
                                    onPressed: _useCurrentLocation,
                                  ),
                                ),
                              ],
                            ),
                          if (_fieldMessage != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _FieldMessage(message: _fieldMessage!),
                          ],
                          if (_ignoredGpsFixes > 0) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '$_ignoredGpsFixes weak GPS fix(es) excluded.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MetricGrid(
                      distanceM: summary.distanceM,
                      direction: _points.length >= 2
                          ? _directionLabel(summary.bearingDegrees)
                          : 'N/A',
                      gpsPoints: _points.length,
                      observations: _selectedObservations.length,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SilvamangCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Mangrove Observations',
                                  style: AppTextStyles.titleMedium,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Attach observations',
                                onPressed: _isLoadingObservations
                                    ? null
                                    : _showObservationPicker,
                                icon: _isLoadingObservations
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_location_alt_rounded,
                                      ),
                              ),
                            ],
                          ),
                          if (_selectedObservations.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'No observations attached.',
                                style: AppTextStyles.bodyMedium,
                              ),
                            )
                          else
                            ..._selectedObservations.entries.map(
                              (entry) => _AttachedObservationTile(
                                observation: entry.value,
                                onRemove: () => setState(
                                  () => _selectedObservations.remove(entry.key),
                                ),
                              ),
                            ),
                          SilvamangButton(
                            text: 'Attach Existing Scans',
                            icon: Icons.eco_rounded,
                            type: SilvamangButtonType.outline,
                            onPressed: _isLoadingObservations
                                ? null
                                : _showObservationPicker,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const _ScientificNote(),
                    const SizedBox(height: AppSpacing.md),
                    SilvamangButton(
                      text: 'Save Transect',
                      icon: Icons.save_rounded,
                      isLoading: transectState.isSaving,
                      onPressed: _isTracking || _points.length < 2
                          ? null
                          : _saveTransect,
                    ),
                    if (transectState.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        transectState.errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.dangerRed,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  String _directionLabel(double? bearing) {
    if (bearing == null) return 'N/A';
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return labels[(bearing / 45).round() % labels.length];
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.isOnline,
    required this.isTracking,
    required this.accuracyM,
  });

  final bool isOnline;
  final bool isTracking;
  final double? accuracyM;

  @override
  Widget build(BuildContext context) {
    final accuracy = accuracyM;
    final goodAccuracy = accuracy != null && accuracy <= 15;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTracking
            ? AppColors.softGreen
            : isOnline
            ? AppColors.softBlue
            : const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(
            isTracking
                ? Icons.gps_fixed_rounded
                : isOnline
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded,
            color: isTracking || isOnline
                ? AppColors.primaryGreen
                : AppColors.warningOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isTracking
                  ? 'Recording  GPS ${accuracy == null ? "acquiring" : "${accuracy.toStringAsFixed(0)} m ${goodAccuracy ? "good" : "fair"}"}'
                  : isOnline
                  ? 'Online  Cloud sync available'
                  : 'Offline  Saving on this device',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsControls extends StatelessWidget {
  const _GpsControls({
    required this.isTracking,
    required this.hasPath,
    required this.onStart,
    required this.onEnd,
    required this.onResume,
  });

  final bool isTracking;
  final bool hasPath;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return SilvamangButton(
      text: isTracking
          ? 'End Transect'
          : hasPath
          ? 'Resume Transect'
          : 'Start Transect',
      icon: isTracking
          ? Icons.stop_circle_rounded
          : hasPath
          ? Icons.play_arrow_rounded
          : Icons.gps_fixed_rounded,
      type: isTracking
          ? SilvamangButtonType.danger
          : SilvamangButtonType.primary,
      onPressed: isTracking
          ? onEnd
          : hasPath
          ? onResume
          : onStart,
    );
  }
}

class _FieldMessage extends StatelessWidget {
  const _FieldMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.mintBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: AppTextStyles.bodySmall),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.distanceM,
    required this.direction,
    required this.gpsPoints,
    required this.observations,
  });

  final double distanceM;
  final String direction;
  final int gpsPoints;
  final int observations;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.15,
      children: [
        _MetricTile(
          label: 'Distance',
          value: '${distanceM.toStringAsFixed(1)} m',
        ),
        _MetricTile(label: 'Direction', value: direction),
        _MetricTile(label: 'GPS Points', value: '$gpsPoints'),
        _MetricTile(label: 'Observations', value: '$observations'),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTextStyles.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _AttachedObservationTile extends StatelessWidget {
  const _AttachedObservationTile({
    required this.observation,
    required this.onRemove,
  });

  final TransectObservationModel observation;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.softGreen,
        child: Icon(
          observation.hasCoordinates
              ? Icons.location_on_rounded
              : Icons.eco_rounded,
          color: AppColors.primaryDarkGreen,
        ),
      ),
      title: Text(
        observation.scientificName.isEmpty
            ? 'Unidentified mangrove'
            : observation.scientificName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(observation.recordCode),
      trailing: IconButton(
        tooltip: 'Remove observation',
        onPressed: onRemove,
        icon: const Icon(Icons.close_rounded),
      ),
    );
  }
}

class _ScientificNote extends StatelessWidget {
  const _ScientificNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, color: Color(0xFF2472B8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'GPS-based digital transect estimation supports field documentation. Follow the required scientific protocol and use calibrated equipment for formal measurements.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
