import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../routing/route_names.dart';

class SilvamangBackButton extends StatelessWidget {
  const SilvamangBackButton({
    super.key,
    this.fallbackRouteName = RouteNames.home,
  });

  final String fallbackRouteName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        tooltip: 'Back',
        onPressed: () => goBack(context, fallbackRouteName: fallbackRouteName),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryDarkGreen,
          shadowColor: AppColors.primaryDarkGreen.withValues(alpha: 0.12),
          elevation: 1,
        ),
      ),
    );
  }

  static void goBack(
    BuildContext context, {
    String fallbackRouteName = RouteNames.home,
  }) {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.goNamed(fallbackRouteName);
  }
}
