import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum SilvamangButtonType {
  primary,
  secondary,
  outline,
  danger,
  success,
  warning,
  neutral,
}

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
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: type == SilvamangButtonType.outline
                  ? AppColors.actionBlue
                  : AppColors.primaryDarkGreen,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(text, textAlign: TextAlign.center)),
            ],
          );

    const size = Size(0, 52);

    if (type == SilvamangButtonType.outline) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: size,
            foregroundColor: AppColors.actionBlue,
          ),
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
      );
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: size,
          foregroundColor: AppColors.primaryDarkGreen,
          backgroundColor: switch (type) {
            SilvamangButtonType.primary => AppColors.primaryDarkGreen,
            SilvamangButtonType.secondary => AppColors.actionBlue,
            SilvamangButtonType.success => AppColors.actionSuccess,
            SilvamangButtonType.warning => AppColors.actionWarning,
            SilvamangButtonType.neutral => AppColors.actionNeutral,
            SilvamangButtonType.danger => AppColors.actionDanger,
            SilvamangButtonType.outline => AppColors.primaryDarkGreen,
          },
        ),
        child: child,
      ),
    );
  }
}
