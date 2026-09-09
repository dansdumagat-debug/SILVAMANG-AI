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
                  'No map SDK is enabled in this phase.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Distribution Map'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            padding: EdgeInsets.zero,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 28,
                    left: 32,
                    child: _MapMarker(
                      color: AppColors.primaryGreen.withValues(alpha: 0.18),
                      size: 96,
                    ),
                  ),
                  Positioned(
                    right: 38,
                    bottom: 30,
                    child: _MapMarker(
                      color: AppColors.successGreen.withValues(alpha: 0.18),
                      size: 120,
                    ),
                  ),
                  const Center(
                    child: Icon(
                      Icons.location_pin,
                      color: AppColors.dangerRed,
                      size: 44,
                    ),
                  ),
                  Positioned(
                    right: AppSpacing.md,
                    top: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Known Distribution',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
