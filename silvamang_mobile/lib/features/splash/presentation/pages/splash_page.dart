import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/silvamang_button.dart';
import '../../../../core/widgets/silvamang_logo.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_checkAuthStatus);
  }

  Future<void> _checkAuthStatus() async {
    final isAuthenticated = await ref
        .read(authControllerProvider.notifier)
        .checkAuthStatus();
    if (!mounted) {
      return;
    }
    context.goNamed(isAuthenticated ? RouteNames.home : RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.mintBackground, AppColors.softGreen],
          ),
        ),
        padding: const EdgeInsets.all(AppConstants.screenPadding),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SilvamangLogo(size: 120),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppStrings.appName,
                style: AppTextStyles.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(AppStrings.tagline, style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Smart Technology for Stronger Mangrove Ecosystems',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              SilvamangButton(
                text: 'Get Started',
                icon: Icons.eco_rounded,
                isLoading: authState.isLoading,
                onPressed: authState.isLoading
                    ? null
                    : () => context.pushNamed(RouteNames.login),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "Let's explore together",
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
