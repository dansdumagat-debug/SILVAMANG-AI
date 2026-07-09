import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum SilvamangBadgeType { success, warning, danger, neutral, info }

class SilvamangBadge extends StatelessWidget {
  const SilvamangBadge({
    super.key,
    required this.label,
    this.type = SilvamangBadgeType.neutral,
  });

  final String label;
  final SilvamangBadgeType type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      SilvamangBadgeType.success => AppColors.successGreen,
      SilvamangBadgeType.warning => AppColors.warningOrange,
      SilvamangBadgeType.danger => AppColors.dangerRed,
      SilvamangBadgeType.info => AppColors.primaryGreen,
      SilvamangBadgeType.neutral => AppColors.mutedText,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
