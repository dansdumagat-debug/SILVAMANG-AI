import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/services/location_service.dart';

final locationControllerProvider =
    StateNotifierProvider<LocationController, LocationState>((ref) {
      return LocationController(locationService: const LocationService());
    });

class LocationState {
  const LocationState({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.locationName = '',
    this.address = '',
    this.source = 'fallback',
    this.isLoading = false,
    this.isUsingFallback = true,
    this.errorMessage,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String locationName;
  final String address;
  final String source;
  final bool isLoading;
  final bool isUsingFallback;
  final String? errorMessage;

  LocationState copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationName,
    String? address,
    String? source,
    bool? isLoading,
    bool? isUsingFallback,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      source: source ?? this.source,
      isLoading: isLoading ?? this.isLoading,
      isUsingFallback: isUsingFallback ?? this.isUsingFallback,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class LocationController extends StateNotifier<LocationState> {
  LocationController({required this.locationService})
    : super(const LocationState());

  final LocationService locationService;

  Future<void> loadCurrentLocation() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final location = await locationService.getCurrentLocationOrFallback();
    _applyLocation(location);
  }

  void useFallbackLocation() {
    _applyLocation(DeviceLocation.fallback());
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void _applyLocation(DeviceLocation location) {
    state = state.copyWith(
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      locationName: location.locationName,
      address: location.address,
      source: location.source,
      isLoading: false,
      isUsingFallback: location.isFallback,
      errorMessage: location.isFallback
          ? 'GPS unavailable. Fallback prototype location will be used.'
          : null,
    );
  }
}
