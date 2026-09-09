import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_back_button.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';

class HelpAboutPage extends StatelessWidget {
  const HelpAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(
        leading: const SilvamangBackButton(
          fallbackRouteName: RouteNames.profile,
        ),
        title: const Text('Help & About'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.softGreen,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: AppColors.primaryDarkGreen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.appName,
                            style: AppTextStyles.titleLarge,
                          ),
                          Text(
                            'Version 1.0.0+1',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'A field companion for mangrove species identification, scan records, location validation, and educational learning.',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _HelpSection(
            icon: Icons.camera_alt_rounded,
            title: 'Scanning',
            items: [
              'Capture a clear mangrove image before running identification.',
              'Use online AI when the server is reachable.',
              'Use offline prediction when field internet is unavailable.',
              'Save the result so it appears in history and on the map.',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _HelpSection(
            icon: Icons.map_rounded,
            title: 'Map Pins',
            items: [
              'Every saved scan with GPS coordinates appears as a pin.',
              'Green pins are synced records.',
              'Orange pins are pending or local records.',
              'Tap a pin to see species, confidence, barangay, date, and sync status.',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _HelpSection(
            icon: Icons.location_on_rounded,
            title: 'Location',
            items: [
              'GPS provides latitude and longitude from the phone.',
              'Barangay names require offline boundary data or a manual note.',
              'Manual barangay is stored separately and is not GPS-verified.',
              'Better sky visibility usually improves GPS accuracy.',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Help', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                SilvamangButton(
                  text: 'Ask AI Assistant',
                  icon: Icons.chat_bubble_rounded,
                  onPressed: () => context.pushNamed(RouteNames.aiAssistant),
                ),
                const SizedBox(height: AppSpacing.sm),
                SilvamangButton(
                  text: 'Open Species Database',
                  icon: Icons.menu_book_rounded,
                  type: SilvamangButtonType.outline,
                  onPressed: () => context.pushNamed(RouteNames.speciesList),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryDarkGreen),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(item, style: AppTextStyles.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
