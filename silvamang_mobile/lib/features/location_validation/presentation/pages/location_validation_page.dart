import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../transects/presentation/widgets/transect_field_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../controllers/location_controller.dart';

class LocationValidationPage extends ConsumerStatefulWidget {
  const LocationValidationPage({super.key});

  @override
  ConsumerState<LocationValidationPage> createState() =>
      _LocationValidationPageState();
}

class _LocationValidationPageState
    extends ConsumerState<LocationValidationPage> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(locationControllerProvider.notifier).loadCurrentLocation(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(
          fallbackRouteName: RouteNames.measurement,
        ),
        title: const Text('Location & Validation'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          SilvamangCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: AppColors.softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primaryDarkGreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Location', style: AppTextStyles.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        locationState.locationName.isEmpty
                            ? 'Location not available'
                            : locationState.locationName,
                        style: AppTextStyles.bodyLarge,
                      ),
                      Text(
                        locationState.address.isEmpty
                            ? 'Address not available'
                            : locationState.address,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${locationState.latitude?.toStringAsFixed(6) ?? 'N/A'}, ${locationState.longitude?.toStringAsFixed(6) ?? 'N/A'}',
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SilvamangBadge(
                        label: locationState.hasLocation
                            ? 'GPS'
                            : 'Location unavailable',
                        type: locationState.hasLocation
                            ? SilvamangBadgeType.success
                            : SilvamangBadgeType.warning,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SilvamangBadge(
                  label: locationState.hasLocation
                      ? 'Ready for Backend Validation'
                      : 'Location unavailable',
                  type: locationState.hasLocation
                      ? SilvamangBadgeType.info
                      : SilvamangBadgeType.warning,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  !locationState.hasLocation
                      ? 'GPS unavailable. No demo coordinates will be used.'
                      : 'Current coordinates can be sent to the Laravel validation engine when saving a scan record.',
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'You can save observations even when location validation is unavailable.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Location Map'),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 360,
            child: TransectFieldMap(
              key: ValueKey(
                '${locationState.latitude},${locationState.longitude}',
              ),
              mapController: _mapController,
              points: const [],
              observations: const [],
              isOnline: true,
              layer: TransectMapLayer.satellite,
              currentLocation: locationState.hasLocation
                  ? LatLng(locationState.latitude!, locationState.longitude!)
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SilvamangButton(
            text: 'Refresh Location',
            icon: Icons.my_location_rounded,
            isLoading: locationState.isLoading,
            onPressed: () => ref
                .read(locationControllerProvider.notifier)
                .loadCurrentLocation(),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => context.pushNamed(RouteNames.aiAssistant),
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text('Ask AI Assistant'),
          ),
        ],
      ),
    );
  }
}
