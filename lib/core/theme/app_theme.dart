import 'package:flutter/material.dart';
import 'app_typography.dart';
import 'eva_palette.dart';

/// EVA Tactile Audio Terminal Theme Configuration
abstract class AppTheme {
  static ThemeData buildTheme(EvaPalette palette) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: palette.bg,
      colorScheme: ColorScheme.dark(
        primary: palette.primary,
        secondary: palette.secondary,
        surface: palette.surface,
        error: palette.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.header.copyWith(color: palette.textPrimary),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      extensions: [palette],
    );
  }

  static ThemeData get darkTheme => buildTheme(EvaPalette.eva01);
}
