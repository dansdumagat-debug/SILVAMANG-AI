import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../constants/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'empty_state.dart';
import 'silvamang_badge.dart';
import 'silvamang_card.dart';

class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    super.key,
    required this.title,
    required this.message,
    this.icon,
  });

  final String title;
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.screenPadding),
        children: [
          SilvamangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SilvamangBadge(
                  label: 'Phase 5 placeholder',
                  type: SilvamangBadgeType.info,
                ),
                const SizedBox(height: AppSpacing.lg),
                EmptyState(title: title, message: message, icon: icon),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Final business logic will be added in later phases.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
