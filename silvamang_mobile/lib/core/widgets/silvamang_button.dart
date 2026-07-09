import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum SilvamangButtonType { primary, secondary, outline, danger }

class SilvamangButton extends StatelessWidget {
  const SilvamangButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.type = SilvamangButtonType.primary,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final SilvamangButtonType type;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          );

    final size = fullWidth ? const Size.fromHeight(52) : null;

    if (type == SilvamangButtonType.outline) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: child,
      );
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: size,
          backgroundColor: switch (type) {
            SilvamangButtonType.primary => AppColors.primaryDarkGreen,
            SilvamangButtonType.secondary => AppColors.primaryGreen,
            SilvamangButtonType.danger => AppColors.dangerRed,
            SilvamangButtonType.outline => AppColors.primaryDarkGreen,
          },
        ),
        child: child,
      ),
    );
  }
}
