import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/location_service.dart';
import '../../../location/data/services/barangay_resolver_service.dart';

final locationControllerProvider =
    StateNotifierProvider<LocationController, LocationState>((ref) {
      return LocationController(
        locationService: const LocationService(),
        barangayResolverService: ref.watch(barangayResolverServiceProvider),
      );
    });

class LocationState {
  const LocationState({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.locationName = '',
    this.address = '',
    this.barangay,
    this.manualBarangay,
    this.barangayStatus = 'Barangay lookup unavailable.',
    this.barangaySource = 'unavailable',
    this.source = '',
    this.timestamp,
    this.statusMessage = 'Location unavailable',
    this.isLoading = false,
    this.isUsingFallback = false,
    this.errorMessage,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String locationName;
  final String address;
  final String? barangay;
  final String? manualBarangay;
  final String barangayStatus;
  final String barangaySource;
  final String source;
  final DateTime? timestamp;
  final String statusMessage;
  final bool isLoading;
  final bool isUsingFallback;
  final String? errorMessage;

  bool get hasLocation => latitude != null && longitude != null;

  LocationState copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationName,
    String? address,
    String? barangay,
    String? manualBarangay,
    String? barangayStatus,
    String? barangaySource,
    String? source,
    DateTime? timestamp,
    String? statusMessage,
    bool? isLoading,
    bool? isUsingFallback,
    String? errorMessage,
    bool clearError = false,
    bool clearLocation = false,
    bool clearManualBarangay = false,
  }) {
    return LocationState(
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
      accuracy: clearLocation ? null : accuracy ?? this.accuracy,
      locationName: clearLocation ? '' : locationName ?? this.locationName,
      address: clearLocation ? '' : address ?? this.address,
      barangay: clearLocation ? null : barangay ?? this.barangay,
      manualBarangay: clearLocation || clearManualBarangay
          ? null
          : manualBarangay ?? this.manualBarangay,
      barangayStatus: barangayStatus ?? this.barangayStatus,
      barangaySource: clearLocation
          ? 'unavailable'
          : barangaySource ?? this.barangaySource,
      source: clearLocation ? '' : source ?? this.source,
      timestamp: clearLocation ? null : timestamp ?? this.timestamp,
      statusMessage: statusMessage ?? this.statusMessage,
      isLoading: isLoading ?? this.isLoading,
      isUsingFallback: isUsingFallback ?? this.isUsingFallback,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class LocationController extends StateNotifier<LocationState> {
  LocationController({
    required this.locationService,
    required this.barangayResolverService,
  }) : super(const LocationState());

  final LocationService locationService;
  final BarangayResolverService barangayResolverService;

  Future<void> loadCurrentLocation() async {
    await captureScanLocation();
  }

  Future<void> captureScanLocation() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearLocation: true,
      statusMessage: 'Capturing location...',
      barangayStatus: 'Barangay lookup unavailable.',
      barangaySource: 'unavailable',
      isUsingFallback: false,
    );
    final result = await locationService.getCurrentLocationResult(
      timeout: const Duration(seconds: 10),
    );

    if (result.location != null) {
      _applyLocation(result.location!);
      final barangayResolution = await barangayResolverService.resolve(
        latitude: result.location!.latitude,
        longitude: result.location!.longitude,
        accuracy: result.location!.accuracy,
      );
      final resolvedBarangay = barangayResolution.barangay;
      final lookupMessage =
          barangayResolution.message ?? barangayResolution.status;
      final resolvedStatusMessage = resolvedBarangay == null
          ? lookupMessage
          : state.accuracy != null && state.accuracy! > 50
          ? 'Location captured, but GPS accuracy is low. Barangay may be uncertain.'
          : barangayResolution.source == 'offline_downloaded_boundary'
          ? 'Offline location captured'
          : 'Location captured';
      state = state.copyWith(
        barangay: resolvedBarangay,
        locationName: resolvedBarangay == null
            ? state.locationName
            : 'Barangay $resolvedBarangay',
        address: resolvedBarangay == null
            ? state.address
            : 'Barangay $resolvedBarangay, GPS captured location',
        barangayStatus: lookupMessage,
        barangaySource: barangayResolution.source,
        statusMessage: resolvedStatusMessage,
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      clearLocation: true,
      source: result.permissionStatus,
      isUsingFallback: false,
      statusMessage: 'Location unavailable',
      barangayStatus: 'Barangay lookup unavailable.',
      barangaySource: 'unavailable',
      errorMessage:
          result.errorMessage ??
          'Location unavailable. Please enable GPS/location permission.',
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void setManualBarangay(String value) {
    final cleanValue = value.trim();
    state = state.copyWith(
      manualBarangay: cleanValue.isEmpty ? null : cleanValue,
      clearManualBarangay: cleanValue.isEmpty,
    );
  }

  void _applyLocation(DeviceLocation location) {
    final statusMessage = location.accuracy > 50
        ? 'GPS accuracy is low. Move to an open area and refresh location.'
        : 'Location captured';

    state = state.copyWith(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      locationName: location.locationName,
      address: location.address,
      source: location.source,
      timestamp: location.timestamp,
      statusMessage: statusMessage,
      isLoading: false,
      isUsingFallback: false,
      errorMessage: null,
    );
  }
}
