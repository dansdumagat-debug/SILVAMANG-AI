import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SilvamangLogo extends StatelessWidget {
  const SilvamangLogo({super.key, this.size = 72, this.showText = false});

  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDarkGreen.withValues(alpha: 0.16),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        AppAssets.logoPlaceholder,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDarkGreen, AppColors.primaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.eco_rounded,
            color: AppColors.mintBackground,
            size: size * 0.44,
          ),
        ),
      ),
    );

    if (!showText) {
      return badge;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: AppSpacing.sm),
        Text('SILVAMANG AI', style: AppTextStyles.titleMedium),
      ],
    );
  }
}
