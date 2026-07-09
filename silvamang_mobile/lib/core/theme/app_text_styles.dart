import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryDarkGreen,
  );

  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static TextStyle get bodyLarge =>
      GoogleFonts.inter(fontSize: 16, height: 1.45, color: AppColors.textDark);

  static TextStyle get bodyMedium =>
      GoogleFonts.inter(fontSize: 14, height: 1.45, color: AppColors.mutedText);

  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 12, height: 1.35, color: AppColors.mutedText);

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryDarkGreen,
  );

  static TextStyle get metricValue => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryDarkGreen,
  );

  static TextStyle get metricLabel => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.mutedText,
  );
}
