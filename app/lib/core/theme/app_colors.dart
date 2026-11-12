import 'package:flutter/material.dart';

/// Semua token warna Droptix — definisi satu tempat.
/// Widget dan layar tidak boleh menulis nilai warna secara langsung.
abstract final class AppColors {
  // Background
  static const Color bg = Color(0xFF010101);
  static const Color glowMid = Color(0xFF0D262B);
  static const Color glowEnd = Color(0xFF103138);

  // Surface
  static const Color surface = Color(0xFF121518);
  static const Color surfaceHigh = Color(0xFF26292C);
  static const Color chipInactive = Color(0xFF3B3B3B);

  // Aksen utama
  static const Color primary = Color(0xFF6CE6DB);
  static const Color onPrimary = Color(0xFF062B28);
  static const Color outlineTeal = Color(0xFF649F99);
  static const Color iconButtonFill = Color(0xFF111D1C);

  // Teks
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF919294);

  // Status
  static const Color urgent = Color(0xFFEC626F);
  static const Color success = Color(0xFF02CC66);

  // Divider / border (putih 12%)
  static const Color divider = Color(0x1FFFFFFF);
}

