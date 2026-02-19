import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Headers - Screen titles use SemiBold (600)
  static TextStyle get h1 => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
  );

  static TextStyle get h2 => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
  );

  static TextStyle get h3 => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.textPrimary,
  );

  // Body - Regular (400)
  static TextStyle get body => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textPrimary,
  );

  static TextStyle get bodySecondary => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textSecondary,
  );

  // Small - Regular (400)
  static TextStyle get caption => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textSecondary,
  );

  static TextStyle get label => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500, // Medium for badges/chips
    color: AppColors.textSecondary,
  );

  // On Card - Card titles use Medium (500)
  static TextStyle get cardTitle => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.textOnCard,
  );

  static TextStyle get cardBody => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.textOnCard,
  );

  // Button text - Medium (500)
  static TextStyle get button => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium
    color: AppColors.primary,
  );
}