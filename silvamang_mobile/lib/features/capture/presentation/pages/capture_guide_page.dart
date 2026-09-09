import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../measurement/presentation/controllers/field_distance_controller.dart';
import '../../data/models/captured_plant_part_image.dart';
import '../controllers/capture_controller.dart';

class CaptureGuidePage extends ConsumerWidget {
  const CaptureGuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captureState = ref.watch(captureControllerProvider);
    final captureController = ref.read(captureControllerProvider.notifier);
    final fieldDistanceState = ref.watch(fieldDistanceControllerProvider);
    final fieldDistanceController = ref.read(
      fieldDistanceControllerProvider.notifier,
    );
    final capturedCount = captureState.capturedCount;
    final distanceMeters = fieldDistanceState.measurement.distanceMeters;

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(),
        title: const Text('Capture Mangrove'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          Text(
            'Capture clear images of key plant parts for better identification.',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Captured $capturedCount of 5 plant parts',
                    style: AppTextStyles.labelLarge,
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: LinearProgressIndicator(
                    value: capturedCount / 5,
                    color: AppColors.primaryGreen,
                    backgroundColor: AppColors.borderSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'At least one image is required. More plant parts improve reliability.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.social_distance_rounded,
                        color: AppColors.primaryDarkGreen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Measure Distance First',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Walk from your standing point to the mangrove/front point for an estimated distance.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  distanceMeters == null
                      ? 'Distance from user to target: Not measured'
                      : 'Distance from user to target: ${distanceMeters.toStringAsFixed(2)} meters',
                  style: AppTextStyles.labelLarge,
                ),
                if (fieldDistanceState.measurement.warningMessage != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    fieldDistanceState.measurement.warningMessage!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warningOrange,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;
                    final measureButton = SilvamangButton(
                      text: distanceMeters == null
                          ? 'Measure Distance'
                          : 'Remeasure',
                      icon: Icons.directions_walk_rounded,
                      fullWidth: isNarrow,
                      onPressed: () =>
                          context.pushNamed(RouteNames.fieldDistance),
                    );
                    final skipButton = SilvamangButton(
                      text: isNarrow ? 'Skip' : 'Skip Distance',
                      icon: Icons.skip_next_rounded,
                      type: SilvamangButtonType.outline,
                      fullWidth: isNarrow,
                      onPressed: () {
                        fieldDistanceController.reset();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Distance measurement skipped.'),
                          ),
                        );
                      },
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          measureButton,
                          const SizedBox(height: AppSpacing.sm),
                          skipButton,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: measureButton),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: skipButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (captureState.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Text(
                captureState.errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.dangerRed,
                ),
              ),
            ),
          ],
          if (captureState.successMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Text(
                captureState.successMessage!,
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          for (final part in _plantParts) ...[
            _PlantPartCaptureCard(
              part: part,
              image: captureState.getImageFor(part.key),
              isPicking: captureState.isPicking,
              onCamera: () => captureController.pickFromCamera(part.key),
              onGallery: () => captureController.pickFromGallery(part.key),
              onRemove: () => captureController.removeImage(part.key),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          const SectionHeader(title: 'Capture Tip'),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.tips_and_updates_rounded,
                    color: AppColors.primaryDarkGreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Use natural lighting and avoid blurry photos for better identification.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Images are used for online or offline identification when you continue.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          SilvamangButton(
            text: 'Continue to Identification',
            icon: Icons.image_search_rounded,
            onPressed: !captureState.isReadyForIdentification
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please capture or select at least one mangrove image.',
                        ),
                      ),
                    );
                  }
                : () => context.pushNamed(RouteNames.identificationResult),
          ),
        ],
      ),
    );
  }
}

const _plantParts = [
  _PlantPartConfig(
    key: 'leaves',
    title: 'Leaves',
    instruction: 'Capture clear leaf shape, color, and arrangement.',
    icon: Icons.eco_rounded,
  ),
  _PlantPartConfig(
    key: 'bark',
    title: 'Bark',
    instruction: 'Capture trunk or bark texture.',
    icon: Icons.forest_rounded,
  ),
  _PlantPartConfig(
    key: 'roots',
    title: 'Roots',
    instruction: 'Capture roots, prop roots, or root structure.',
    icon: Icons.grass_rounded,
  ),
  _PlantPartConfig(
    key: 'flowers',
    title: 'Flowers',
    instruction: 'Capture flowers or reproductive parts if visible.',
    icon: Icons.local_florist_rounded,
  ),
  _PlantPartConfig(
    key: 'canopy',
    title: 'Canopy / Full Tree',
    instruction: 'Capture full tree or canopy view.',
    icon: Icons.park_rounded,
  ),
];

class _PlantPartConfig {
  const _PlantPartConfig({
    required this.key,
    required this.title,
    required this.instruction,
    required this.icon,
  });

  final String key;
  final String title;
  final String instruction;
  final IconData icon;
}

class _PlantPartCaptureCard extends StatelessWidget {
  const _PlantPartCaptureCard({
    required this.part,
    required this.image,
    required this.isPicking,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final _PlantPartConfig part;
  final CapturedPlantPartImage? image;
  final bool isPicking;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.softGreen,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  part.icon,
                  color: AppColors.primaryDarkGreen,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(part.title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(part.instruction, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (image == null)
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                color: AppColors.primaryGreen,
                size: 42,
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                image!.previewBytes,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          if (image != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    image!.source == 'camera' ? 'Camera' : 'Gallery',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(image!.fileName, style: AppTextStyles.bodySmall),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SilvamangButton(
                  text: 'Capture',
                  icon: Icons.camera_alt_rounded,
                  fullWidth: false,
                  isLoading: isPicking,
                  onPressed: isPicking ? null : onCamera,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SilvamangButton(
                  text: 'Gallery',
                  icon: Icons.photo_library_rounded,
                  type: SilvamangButtonType.outline,
                  fullWidth: false,
                  isLoading: isPicking,
                  onPressed: isPicking ? null : onGallery,
                ),
              ),
            ],
          ),
          if (image != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove'),
            ),
          ],
        ],
      ),
    );
  }
}
