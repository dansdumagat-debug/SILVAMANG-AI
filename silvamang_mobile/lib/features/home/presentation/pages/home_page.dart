import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/silvamang_card.dart';
import '../../../../core/widgets/silvamang_logo.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../offline_sync/presentation/controllers/offline_sync_controller.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _offlineRefreshAttempted = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(offlineSyncControllerProvider.notifier).loadQueue(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final offlineState = ref.watch(offlineSyncControllerProvider);
    final notificationCount =
        offlineState.pendingCount +
        offlineState.failedCount +
        offlineState.recentlyDeletedCount +
        (authState.isOfflineSession ? 1 : 0);

    if (authState.isOfflineSession && !_offlineRefreshAttempted) {
      _offlineRefreshAttempted = true;
      Future.microtask(() {
        if (!mounted) {
          return;
        }
        ref.read(authControllerProvider.notifier).refreshCurrentUser();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.mintBackground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          AppConstants.screenPadding,
          112,
        ),
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                const SilvamangLogo(size: 44),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello!', style: AppTextStyles.displayLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        "Let's identify mangrove species and learn more about them.",
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => context.pushNamed(RouteNames.notifications),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: AppColors.primaryDarkGreen,
                          ),
                        ),
                        if (notificationCount > 0)
                          Positioned(
                            right: 0,
                            top: -2,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.dangerRed,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Center(
                                child: Text(
                                  notificationCount > 9
                                      ? '9+'
                                      : notificationCount.toString(),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (authState.isOfflineSession) ...[
            const SizedBox(height: AppSpacing.md),
            SilvamangCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.warningOrange,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Offline session active. Your data will sync when connection is restored.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          SilvamangCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            onTap: () => context.pushNamed(RouteNames.captureGuide),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDarkGreen, AppColors.primaryGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Identify Mangrove',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Take a photo to identify species',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.28,
            children: [
              _QuickActionCard(
                title: 'Measure',
                subtitle: 'Height & Canopy Estimation',
                icon: Icons.straighten_rounded,
                background: AppColors.softGreen,
                onTap: () => context.pushNamed(RouteNames.measurement),
              ),
              _QuickActionCard(
                title: 'My Records',
                subtitle: 'View History',
                icon: Icons.history_rounded,
                background: AppColors.softBlue,
                onTap: () => context.pushNamed(RouteNames.records),
              ),
              _QuickActionCard(
                title: 'Mangrove Map',
                subtitle: 'View scan pins',
                icon: Icons.map_rounded,
                background: const Color(0xFFE8F6F1),
                onTap: () => context.pushNamed(RouteNames.map),
              ),
              _QuickActionCard(
                title: 'Species Guide',
                subtitle: 'Browse Mangrove Species',
                icon: Icons.menu_book_rounded,
                background: const Color(0xFFFFF7E8),
                onTap: () => context.pushNamed(RouteNames.speciesList),
              ),
              _QuickActionCard(
                title: 'AI Assistant',
                subtitle: 'Ask about mangroves',
                icon: Icons.chat_bubble_rounded,
                background: const Color(0xFFEFF5FF),
                onTap: () => context.pushNamed(RouteNames.aiAssistant),
              ),
              _QuickActionCard(
                title: 'Offline Queue',
                subtitle: 'View pending sync items',
                icon: Icons.cloud_queue_rounded,
                background: const Color(0xFFFFF4EA),
                onTap: () => context.pushNamed(RouteNames.offlineQueue),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Mini Stats'),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              Expanded(
                child: MetricCard(
                  title: 'Total Scans',
                  value: '34,120',
                  icon: Icons.camera_alt_rounded,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricCard(
                  title: 'AI Accuracy',
                  value: '91.7%',
                  icon: Icons.verified_rounded,
                  color: AppColors.successGreen,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: MetricCard(
                  title: 'Species',
                  value: '80',
                  icon: Icons.eco_rounded,
                  color: AppColors.warningOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SilvamangCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primaryDarkGreen),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
