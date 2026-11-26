import 'package:flutter/material.dart';

/// Semua token warna Droptix — definisi satu tempat.
/// Background solid gelap pekat tanpa gradasi, aksen Biru-Teal (#6CE6DB),
/// dan permukaan kartu bertint teal gelap dengan gradasi halus.
abstract final class AppColors {
  // Background solid gelap pekat (tanpa gradasi)
  static const Color bg = Color(0xFF080B0D);
  static const Color glowMid = Color(0xFF080B0D);
  static const Color glowEnd = Color(0xFF080B0D);

  // Surface (tinted teal gelap dengan gradasi halus pada kartu)
  static const Color surface = Color(0xFF10191C);
  static const Color surfaceGradStart = Color(0xFF152428);
  static const Color surfaceGradEnd = Color(0xFF0E1619);
  static const Color surfaceHigh = Color(0xFF182529);
  static const Color navBar = Color(0xFF0A0E10);
  static const Color chipInactive = Color(0xFF233135);

  /// Gradasi kartu halus dalam keluarga biru-teal gelap.
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceGradStart, surfaceGradEnd],
  );

  // Aksen utama (Biru-Teal Droptix)
  static const Color primary = Color(0xFF6CE6DB);
  static const Color primaryMuted = Color(0xFF5CAFA8);
  static const Color onPrimary = Color(0xFF062B28);
  static const Color outlineTeal = Color(0xFF649F99);
  static const Color iconButtonFill = Color(0xFF111D1C);

  // Teks
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF919E9F);

  // Status
  static const Color urgent = Color(0xFFEC626F);
  static const Color success = Color(0xFF02CC66);

  // Divider / border halus
  static const Color divider = Color(0x1FFFFFFF);
}
