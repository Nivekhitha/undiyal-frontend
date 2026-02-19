import 'package:flutter/cupertino.dart';

class AppColors {
  // Blue-based Zenith Palette
  // Primary Colors
  static const Color primary = Color(0xFF0D47A1); // Primary Blue
  static const Color primaryAccent = Color(0xFF2196F3); // Accent Blue
  static const Color primaryLight = Color(0xFFE3F2FD); // Surface Blue

  // Backgrounds
  static const Color background = Color(0xFFF4F6F8); // Background
  static const Color cardBackground = Color(0xFFFFFFFF); // Card White

  // Text
  static const Color textPrimary = Color(0xFF0F172A); // Text Primary
  static const Color textSecondary = Color(0xFF64748B); // Text Secondary
  static const Color textOnCard = Color(0xFF0F172A);
  static const Color textLight = Color(0xFF64748B);

  // Urgency / Alerts
  static const Color urgent = Color(0xFFF87171); // Urgent Red
  static const Color urgentBackground = Color(0xFFFEE2E2); // Urgent BG

  // Functional (keeping existing for compatibility)
  static const Color success = Color(0xFF10B981); // Green
  static const Color error = Color(0xFFF87171); // Updated to match urgent
  static const Color warning = Color(0xFFF59E0B); // Orange
  static const Color info = Color(0xFF2196F3); // Updated to accent blue

  // Chart colors
  static const Color chartBar = Color(0xFF2196F3); // Accent Blue
  static const Color chartInactive = Color(0xFFE2E8F0);
  static const Color chartSecondary = Color(0xFF0D47A1); // Primary Blue
  
  // Borders and Dividers
  static const Color border = Color(0xFFE2E8F0); // Divider/Border
  static const Color divider = Color(0xFFE2E8F0);
}