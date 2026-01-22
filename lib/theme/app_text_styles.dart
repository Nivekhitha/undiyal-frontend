import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Headers
  static TextStyle get h1 => GoogleFonts.urbanist(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get h2 => GoogleFonts.urbanist(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get h3 => GoogleFonts.urbanist(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body
  static TextStyle get body => GoogleFonts.urbanist(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySecondary => GoogleFonts.urbanist(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Small
  static TextStyle get caption => GoogleFonts.urbanist(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get label => GoogleFonts.urbanist(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // On Card
  static TextStyle get cardTitle => GoogleFonts.urbanist(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnCard,
  );

  static TextStyle get cardBody => GoogleFonts.urbanist(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnCard,
  );
}