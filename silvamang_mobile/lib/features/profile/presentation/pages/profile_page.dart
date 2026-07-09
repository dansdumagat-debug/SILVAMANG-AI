import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/silvamang_badge.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final displayName = user?.name.isNotEmpty == true
        ? user!.name
        : 'Mobile User';
    final displayEmail = user?.email.isNotEmpty == true
        ? user!.email
        : 'user@silvamang.test';
    final role = user?.roles.isNotEmpty == true
        ? user!.roles.first
        : 'Mobile User';

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      appBar: AppBar(title: const Text('Profile')),
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
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    color: AppColors.softGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryDarkGreen,
                    size: 54,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(displayName, style: AppTextStyles.titleLarge),
                Text(displayEmail, style: AppTextStyles.bodyMedium),
                const SizedBox(height: AppSpacing.md),
                SilvamangBadge(label: role, type: SilvamangBadgeType.info),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Records',
                  value: '12',
                  icon: Icons.history_rounded,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricCard(
                  title: 'Species',
                  value: '8',
                  icon: Icons.eco_rounded,
                  color: AppColors.successGreen,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricCard(
                  title: 'Synced',
                  value: '10',
                  icon: Icons.cloud_done_rounded,
                  color: AppColors.warningOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _MenuCard(
            icon: Icons.history_rounded,
            label: 'My Records',
            onTap: () => context.goNamed(RouteNames.records),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MenuCard(
            icon: Icons.cloud_queue_rounded,
            label: 'Offline Queue',
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.sm),
          _MenuCard(
            icon: Icons.settings_rounded,
            label: 'App Settings',
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.sm),
          _MenuCard(
            icon: Icons.help_outline_rounded,
            label: 'Help & About',
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.lg),
          SilvamangButton(
            text: 'Logout',
            icon: Icons.logout_rounded,
            isLoading: authState.isLoading,
            type: SilvamangButtonType.outline,
            onPressed: authState.isLoading
                ? null
                : () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) {
                      context.goNamed(RouteNames.login);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primaryDarkGreen),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTextStyles.labelLarge)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
        ],
      ),
    );
  }
}
