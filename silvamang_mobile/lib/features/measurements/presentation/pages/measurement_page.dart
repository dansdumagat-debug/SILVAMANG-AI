import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';

class MeasurementPage extends StatelessWidget {
  const MeasurementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Measurements')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          SilvamangCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: AppColors.softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.park_rounded,
                    color: AppColors.primaryDarkGreen,
                    size: 86,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Mock AI Measurement Estimate',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Mock AI Measurement Estimate'),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Height',
                  value: '6.8 m',
                  icon: Icons.height_rounded,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Canopy',
                  value: '4.2 m',
                  icon: Icons.width_wide_rounded,
                  color: AppColors.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Method',
                  value: 'Depth',
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.warningOrange,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: MetricCard(
                  title: 'Confidence',
                  value: '88%',
                  icon: Icons.verified_rounded,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SilvamangCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primaryDarkGreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'These values are mock estimates for prototype testing.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SilvamangButton(
            text: 'Continue to Location Validation',
            icon: Icons.location_on_rounded,
            onPressed: () => context.goNamed(RouteNames.locationValidation),
          ),
        ],
      ),
    );
  }
}
