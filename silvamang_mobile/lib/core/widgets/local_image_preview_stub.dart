import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class LocalImagePreview extends StatelessWidget {
  const LocalImagePreview({
    super.key,
    this.imagePath,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final String? imagePath;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.softGreen,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: AppColors.primaryDarkGreen,
      ),
    );
  }
}
