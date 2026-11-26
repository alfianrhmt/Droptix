import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Token tipografi Droptix.
/// Font: Plus Jakarta Sans — ramping, bersih, dengan hierarki tenang.
abstract final class AppTextStyles {
  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        height: 21 / 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        height: 18 / 12.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get label => GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        height: 19 / 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
        fontSize: 11.5,
        height: 16 / 11.5,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );
}

