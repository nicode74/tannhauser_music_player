import 'package:flutter/material.dart';
import 'app_colors.dart';

/// EVA-01 Tactile Audio Terminal Typography
/// Geometric Sans for metadata; Monospace for technical telemetry.
abstract class AppTypography {
  // UI & Metadata (Sans-serif)
  static const TextStyle header = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle trackTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle trackArtist = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Telemetry & Technical Readouts (Monospace)
  static const TextStyle telemetryLarge = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.textPrimary,
  );

  static const TextStyle telemetryMedium = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle telemetrySmall = TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.textSecondary,
  );

  static const TextStyle codeSnippet = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle statusPill = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
}
