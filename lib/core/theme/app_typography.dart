import 'package:flutter/material.dart';

/// EVA Tactile Audio Terminal Typography
/// Geometric Sans for metadata; Monospace for technical telemetry.
abstract class AppTypography {
  static const Color _defaultTextPrimary = Color(0xFFF3F2F8);
  static const Color _defaultTextSecondary = Color(0xFF948FA8);

  // UI & Metadata (Sans-serif)
  static const TextStyle header = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: _defaultTextPrimary,
  );

  static const TextStyle trackTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: _defaultTextPrimary,
  );

  static const TextStyle trackArtist = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: _defaultTextSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: _defaultTextPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: _defaultTextSecondary,
  );

  // Telemetry & Technical Readouts (Monospace)
  static const TextStyle telemetryLarge = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: _defaultTextPrimary,
  );

  static const TextStyle telemetryMedium = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: _defaultTextPrimary,
  );

  static const TextStyle telemetrySmall = TextStyle(
    fontFamily: 'monospace',
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: _defaultTextSecondary,
  );

  static const TextStyle codeSnippet = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: _defaultTextPrimary,
  );

  static const TextStyle statusPill = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
}
