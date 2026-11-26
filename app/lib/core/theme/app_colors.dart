import 'package:flutter/material.dart';

/// Semua token warna Droptix — definisi satu tempat.
/// Palet Deep Midnight Blue dengan tinted surface bergradasi halus
/// dan aksen biru cerah yang harmonis.
abstract final class AppColors {
  // Background (hitam pekat bertint biru malam + ambient glow halus)
  static const Color bg = Color(0xFF05080D);
  static const Color glowMid = Color(0xFF0A1929);
  static const Color glowEnd = Color(0xFF0F263D);

  // Surface (tinted blue-slate dengan gradasi halus, bukan abu-abu netral)
  static const Color surface = Color(0xFF0F1B29);
  static const Color surfaceGradStart = Color(0xFF16283D);
  static const Color surfaceGradEnd = Color(0xFF0D1724);
  static const Color surfaceHigh = Color(0xFF192C42);
  static const Color navBar = Color(0xFF070C14);
  static const Color chipInactive = Color(0xFF1E3248);

  /// Gradasi kartu lembut kiri-atas ke kanan-bawah untuk kedalaman tanpa border kasar.
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceGradStart, surfaceGradEnd],
  );

  // Aksen utama (biru cerah + versi redup untuk tautan sekunder)
  static const Color primary = Color(0xFF4BA8FF);
  static const Color primaryMuted = Color(0xFF6B9FD1);
  static const Color onPrimary = Color(0xFF041729);
  static const Color outlineTeal = Color(0xFF2D5578);
  static const Color iconButtonFill = Color(0xFF102033);

  // Teks
  static const Color textPrimary = Color(0xFFF4F8FC);
  static const Color textSecondary = Color(0xFF8A9FB5);

  // Status
  static const Color urgent = Color(0xFFF06478);
  static const Color success = Color(0xFF22D38A);

  // Divider / border halus bertint biru
  static const Color divider = Color(0x1C8AB8E6);
}
