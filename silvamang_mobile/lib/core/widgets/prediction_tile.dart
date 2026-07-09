import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'silvamang_card.dart';

class PredictionTile extends StatelessWidget {
  const PredictionTile({
    super.key,
    required this.rank,
    required this.scientificName,
    required this.commonName,
    required this.confidence,
  });

  final int rank;
  final String scientificName;
  final String commonName;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final normalized = (confidence / 100).clamp(0.0, 1.0);
    return SilvamangCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.softGreen,
            child: Text('#$rank', style: AppTextStyles.labelLarge),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scientificName, style: AppTextStyles.titleMedium),
                Text(commonName, style: AppTextStyles.bodySmall),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: normalized,
                  color: AppColors.primaryGreen,
                  backgroundColor: AppColors.borderSoft,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('${confidence.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }
}
