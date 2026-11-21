import 'package:flutter/material.dart';

/// EVA-01 Tactile Audio Terminal Color Palette
/// Strict compliance with docs/ui_style.md
abstract class AppColors {
  // Canvas & Surfaces
  static const Color bg = Color(0xFF0A090E);
  static const Color surface = Color(0xFF13111C);
  static const Color surfaceInset = Color(0xFF0D0C14);
  static const Color border = Color(0xFF262236);
  static const Color borderStrong = Color(0xFF3B3454);

  // Typography
  static const Color textPrimary = Color(0xFFF3F2F8);
  static const Color textSecondary = Color(0xFF948FA8);
  static const Color textMuted = Color(0xFF565169);

  // EVA-01 Terminal Accents
  static const Color evaPurple = Color(0xFF8B5CF6);
  static const Color evaPurpleDim = Color(0xFF3B1E6D);
  static const Color acidGreen = Color(0xFF4ADE80);
  static const Color acidGreenDim = Color(0xFF1B4D2E);
  static const Color hazardOrange = Color(0xFFF59E0B);
  static const Color hazardOrangeDim = Color(0xFF4D3208);
  static const Color errorRed = Color(0xFFEF4444);
}
