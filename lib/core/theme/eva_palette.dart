import 'package:flutter/material.dart';

/// Evangelion Unit-themed Color Palette ThemeExtension (EVA-00 through EVA-13)
/// Maintains 85% matte OLED dark surfaces per docs/ui_style.md while
/// customizing primary, secondary, warning, and subtle surface/border tints.
@immutable
class EvaPalette extends ThemeExtension<EvaPalette> {
  final String id;
  final String unitCode;
  final String name;
  final String subtitle;

  // Canvas & Surfaces
  final Color bg;
  final Color surface;
  final Color surfaceInset;
  final Color border;
  final Color borderStrong;

  // Typography
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Semantic Terminal Accents
  final Color primary;
  final Color primaryDim;
  final Color secondary;
  final Color secondaryDim;
  final Color warning;
  final Color warningDim;
  final Color error;

  const EvaPalette({
    required this.id,
    required this.unitCode,
    required this.name,
    required this.subtitle,
    required this.bg,
    required this.surface,
    required this.surfaceInset,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryDim,
    required this.secondary,
    required this.secondaryDim,
    required this.warning,
    required this.warningDim,
    required this.error,
  });

  // Backwards-friendly semantic aliases matching original EVA-01 naming
  Color get evaPurple => primary;
  Color get evaPurpleDim => primaryDim;
  Color get acidGreen => secondary;
  Color get acidGreenDim => secondaryDim;
  Color get hazardOrange => warning;
  Color get hazardOrangeDim => warningDim;
  Color get errorRed => error;

  static const Color _defaultTextPrimary = Color(0xFFF3F2F8);
  static const Color _defaultTextSecondary = Color(0xFF948FA8);
  static const Color _defaultTextMuted = Color(0xFF565169);
  static const Color _defaultError = Color(0xFFEF4444);

  /// EVA-00 (Prototype — Amber / Orange)
  static const EvaPalette eva00Proto = EvaPalette(
    id: 'eva_00_proto',
    unitCode: 'UNIT-00',
    name: 'EVA-00 PROTOTYPE',
    subtitle: 'Prototype Amber & Signal Yellow',
    bg: Color(0xFF0C0A08),
    surface: Color(0xFF171310),
    surfaceInset: Color(0xFF100D0A),
    border: Color(0xFF30261D),
    borderStrong: Color(0xFF4A3A2B),
    textPrimary: Color(0xFFF6F3EE),
    textSecondary: Color(0xFFA89C8E),
    textMuted: Color(0xFF685D52),
    primary: Color(0xFFF97316),
    primaryDim: Color(0xFF572607),
    secondary: Color(0xFFFACC15),
    secondaryDim: Color(0xFF4D3E06),
    warning: Color(0xFF38BDF8),
    warningDim: Color(0xFF0E3C52),
    error: _defaultError,
  );

  /// EVA-00' (Rebuild / Post-Ramiel — Cobalt Blue & Ice Cyan)
  static const EvaPalette eva00Blue = EvaPalette(
    id: 'eva_00_blue',
    unitCode: 'UNIT-00′',
    name: 'EVA-00′ REBUILD',
    subtitle: 'Cobalt Blue & Ice Cyan',
    bg: Color(0xFF080A0F),
    surface: Color(0xFF101520),
    surfaceInset: Color(0xFF0B0E16),
    border: Color(0xFF1F2B40),
    borderStrong: Color(0xFF304363),
    textPrimary: Color(0xFFF0F5FA),
    textSecondary: Color(0xFF8EA1B8),
    textMuted: Color(0xFF516175),
    primary: Color(0xFF3B82F6),
    primaryDim: Color(0xFF142E5C),
    secondary: Color(0xFF38BDF8),
    secondaryDim: Color(0xFF113D54),
    warning: Color(0xFFF59E0B),
    warningDim: Color(0xFF4D3208),
    error: _defaultError,
  );

  /// EVA-01 (Test Type — Default Original)
  static const EvaPalette eva01 = EvaPalette(
    id: 'eva_01',
    unitCode: 'UNIT-01',
    name: 'EVA-01 TEST TYPE',
    subtitle: 'NERV Purple & Acid Green',
    bg: Color(0xFF0A090E),
    surface: Color(0xFF13111C),
    surfaceInset: Color(0xFF0D0C14),
    border: Color(0xFF262236),
    borderStrong: Color(0xFF3B3454),
    textPrimary: _defaultTextPrimary,
    textSecondary: _defaultTextSecondary,
    textMuted: _defaultTextMuted,
    primary: Color(0xFF8B5CF6),
    primaryDim: Color(0xFF3B1E6D),
    secondary: Color(0xFF4ADE80),
    secondaryDim: Color(0xFF1B4D2E),
    warning: Color(0xFFF59E0B),
    warningDim: Color(0xFF4D3208),
    error: _defaultError,
  );

  /// EVA-02 (Production Model — Asuka Crimson & Signal Orange)
  static const EvaPalette eva02 = EvaPalette(
    id: 'eva_02',
    unitCode: 'UNIT-02',
    name: 'EVA-02 PRODUCTION',
    subtitle: 'Crimson Red & Signal Orange',
    bg: Color(0xFF0D080A),
    surface: Color(0xFF1A1014),
    surfaceInset: Color(0xFF120B0D),
    border: Color(0xFF361E24),
    borderStrong: Color(0xFF542D36),
    textPrimary: Color(0xFFFAF2F3),
    textSecondary: Color(0xFFB39196),
    textMuted: Color(0xFF6E5358),
    primary: Color(0xFFEF4444),
    primaryDim: Color(0xFF591418),
    secondary: Color(0xFFFB923C),
    secondaryDim: Color(0xFF572E10),
    warning: Color(0xFFFACC15),
    warningDim: Color(0xFF4D3E06),
    error: Color(0xFFFF6B6B),
  );

  /// EVA-03 (Bardiel — Obsidian Indigo & Corruption Rose)
  static const EvaPalette eva03 = EvaPalette(
    id: 'eva_03',
    unitCode: 'UNIT-03',
    name: 'EVA-03 BARDIEL',
    subtitle: 'Obsidian Indigo & Stark Silver',
    bg: Color(0xFF08090D),
    surface: Color(0xFF11131C),
    surfaceInset: Color(0xFF0B0C12),
    border: Color(0xFF232738),
    borderStrong: Color(0xFF363D57),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF525D73),
    primary: Color(0xFF6366F1),
    primaryDim: Color(0xFF23255C),
    secondary: Color(0xFFE2E8F0),
    secondaryDim: Color(0xFF3B4252),
    warning: Color(0xFFF43F5E),
    warningDim: Color(0xFF571220),
    error: _defaultError,
  );

  /// EVA-04 (Silver / Electric Cyan)
  static const EvaPalette eva04 = EvaPalette(
    id: 'eva_04',
    unitCode: 'UNIT-04',
    name: 'EVA-04 SILVER',
    subtitle: 'Brushed Platinum & Electric Cyan',
    bg: Color(0xFF090B0D),
    surface: Color(0xFF12161A),
    surfaceInset: Color(0xFF0C0F12),
    border: Color(0xFF252D36),
    borderStrong: Color(0xFF3B4754),
    textPrimary: Color(0xFFF4F7FA),
    textSecondary: Color(0xFF9AA5B1),
    textMuted: Color(0xFF5A6570),
    primary: Color(0xFFCBD5E1),
    primaryDim: Color(0xFF38424F),
    secondary: Color(0xFF22D3EE),
    secondaryDim: Color(0xFF0B4652),
    warning: Color(0xFFF87171),
    warningDim: Color(0xFF541F1F),
    error: _defaultError,
  );

  /// EVA-05 (Provisional Unit-05 — Olive Lime & Ochre Gold)
  static const EvaPalette eva05 = EvaPalette(
    id: 'eva_05',
    unitCode: 'UNIT-05',
    name: 'EVA-05 PROVISIONAL',
    subtitle: 'Tactical Lime & Ochre Gold',
    bg: Color(0xFF080B08),
    surface: Color(0xFF101711),
    surfaceInset: Color(0xFF0B100B),
    border: Color(0xFF213022),
    borderStrong: Color(0xFF344D36),
    textPrimary: Color(0xFFF2F7F2),
    textSecondary: Color(0xFF93A894),
    textMuted: Color(0xFF536654),
    primary: Color(0xFF84CC16),
    primaryDim: Color(0xFF2D4707),
    secondary: Color(0xFFEAB308),
    secondaryDim: Color(0xFF4D3B03),
    warning: Color(0xFFFB923C),
    warningDim: Color(0xFF572E10),
    error: _defaultError,
  );

  /// EVA-06 (Mark.06 — Midnight Cobalt & Solar Gold)
  static const EvaPalette eva06 = EvaPalette(
    id: 'eva_06',
    unitCode: 'MARK.06',
    name: 'EVA MARK.06',
    subtitle: 'Midnight Cobalt & Solar Gold',
    bg: Color(0xFF070910),
    surface: Color(0xFF0F1321),
    surfaceInset: Color(0xFF0A0D17),
    border: Color(0xFF1E2642),
    borderStrong: Color(0xFF2F3C66),
    textPrimary: Color(0xFFF0F4FA),
    textSecondary: Color(0xFF8F9CB8),
    textMuted: Color(0xFF505C78),
    primary: Color(0xFF4F46E5),
    primaryDim: Color(0xFF1D1959),
    secondary: Color(0xFFFBBF24),
    secondaryDim: Color(0xFF523D08),
    warning: Color(0xFF38BDF8),
    warningDim: Color(0xFF0E3C52),
    error: _defaultError,
  );

  /// EVA-07 (Mark.07 — Ash Bone & Rust Amber)
  static const EvaPalette eva07 = EvaPalette(
    id: 'eva_07',
    unitCode: 'MARK.07',
    name: 'EVA MARK.07',
    subtitle: 'Ash Bone & Rust Amber',
    bg: Color(0xFF0B0A09),
    surface: Color(0xFF151311),
    surfaceInset: Color(0xFF0E0D0C),
    border: Color(0xFF2B2723),
    borderStrong: Color(0xFF453E38),
    textPrimary: Color(0xFFF5F2EE),
    textSecondary: Color(0xFFA39B93),
    textMuted: Color(0xFF635D57),
    primary: Color(0xFFA8A29E),
    primaryDim: Color(0xFF3D3936),
    secondary: Color(0xFFEA580C),
    secondaryDim: Color(0xFF521E04),
    warning: Color(0xFF2DD4BF),
    warningDim: Color(0xFF0D4740),
    error: _defaultError,
  );

  /// EVA-08 (Unit-08 — Rose Magenta & Electric Mint)
  static const EvaPalette eva08 = EvaPalette(
    id: 'eva_08',
    unitCode: 'UNIT-08',
    name: 'EVA-08 CUSTOM',
    subtitle: 'Rose Magenta & Electric Mint',
    bg: Color(0xFF0D080B),
    surface: Color(0xFF1A1016),
    surfaceInset: Color(0xFF120B0F),
    border: Color(0xFF361F2E),
    borderStrong: Color(0xFF542E47),
    textPrimary: Color(0xFFFAF2F7),
    textSecondary: Color(0xFFB38FA6),
    textMuted: Color(0xFF6E5264),
    primary: Color(0xFFEC4899),
    primaryDim: Color(0xFF571637),
    secondary: Color(0xFF34D399),
    secondaryDim: Color(0xFF0F4A35),
    warning: Color(0xFFFB7185),
    warningDim: Color(0xFF571D28),
    error: _defaultError,
  );

  /// EVA-09 (Mark.09 — Vessel of the Adams / Scythe Orange & Red)
  static const EvaPalette eva09 = EvaPalette(
    id: 'eva_09',
    unitCode: 'MARK.09',
    name: 'EVA MARK.09',
    subtitle: 'Adams Orange & Scythe Crimson',
    bg: Color(0xFF0C0907),
    surface: Color(0xFF17110E),
    surfaceInset: Color(0xFF100C09),
    border: Color(0xFF30231B),
    borderStrong: Color(0xFF4D372A),
    textPrimary: Color(0xFFFAF4EE),
    textSecondary: Color(0xFFAD998B),
    textMuted: Color(0xFF6B5C52),
    primary: Color(0xFFF97316),
    primaryDim: Color(0xFF572607),
    secondary: Color(0xFFDC2626),
    secondaryDim: Color(0xFF520D0D),
    warning: Color(0xFFFBBF24),
    warningDim: Color(0xFF523D08),
    error: Color(0xFFFF6B6B),
  );

  /// EVA-10 (Mark.10 — Maroon Crimson & Steel White)
  static const EvaPalette eva10 = EvaPalette(
    id: 'eva_10',
    unitCode: 'MARK.10',
    name: 'EVA MARK.10',
    subtitle: 'Maroon Crimson & Steel White',
    bg: Color(0xFF0C080A),
    surface: Color(0xFF170F13),
    surfaceInset: Color(0xFF100A0D),
    border: Color(0xFF331D26),
    borderStrong: Color(0xFF4F2C3B),
    textPrimary: Color(0xFFFAF2F5),
    textSecondary: Color(0xFFB0909D),
    textMuted: Color(0xFF6B525C),
    primary: Color(0xFFE11D48),
    primaryDim: Color(0xFF520A1B),
    secondary: Color(0xFFE2E8F0),
    secondaryDim: Color(0xFF3B4252),
    warning: Color(0xFFF59E0B),
    warningDim: Color(0xFF4D3208),
    error: _defaultError,
  );

  /// EVA-11 (Mark.11 — Sky Cobalt & Acid Lime)
  static const EvaPalette eva11 = EvaPalette(
    id: 'eva_11',
    unitCode: 'MARK.11',
    name: 'EVA MARK.11',
    subtitle: 'Sky Cobalt & Acid Lime',
    bg: Color(0xFF070A0D),
    surface: Color(0xFF0F151C),
    surfaceInset: Color(0xFF0A0E13),
    border: Color(0xFF1E2B38),
    borderStrong: Color(0xFF2E4357),
    textPrimary: Color(0xFFF0F6FA),
    textSecondary: Color(0xFF8FA2B3),
    textMuted: Color(0xFF51616E),
    primary: Color(0xFF0EA5E9),
    primaryDim: Color(0xFF063B54),
    secondary: Color(0xFFA3E635),
    secondaryDim: Color(0xFF37520D),
    warning: Color(0xFFCBD5E1),
    warningDim: Color(0xFF38424F),
    error: _defaultError,
  );

  /// EVA-12 (Mark.12 — Amethyst Violet & Cyan)
  static const EvaPalette eva12 = EvaPalette(
    id: 'eva_12',
    unitCode: 'MARK.12',
    name: 'EVA MARK.12',
    subtitle: 'Slate Amethyst & Tactical Cyan',
    bg: Color(0xFF09080E),
    surface: Color(0xFF12101C),
    surfaceInset: Color(0xFF0C0B14),
    border: Color(0xFF252138),
    borderStrong: Color(0xFF393257),
    textPrimary: Color(0xFFF3F2FA),
    textSecondary: Color(0xFF9691B0),
    textMuted: Color(0xFF58536E),
    primary: Color(0xFF7C3AED),
    primaryDim: Color(0xFF2E1459),
    secondary: Color(0xFF06B6D4),
    secondaryDim: Color(0xFF04414D),
    warning: Color(0xFF94A3B8),
    warningDim: Color(0xFF2F3742),
    error: _defaultError,
  );

  /// EVA-13 (Double Entry — Deep Violet, Dual-Core Crimson & Cyan)
  static const EvaPalette eva13 = EvaPalette(
    id: 'eva_13',
    unitCode: 'UNIT-13',
    name: 'EVA-13 DOUBLE ENTRY',
    subtitle: 'Deep Violet & Dual-Core Crimson',
    bg: Color(0xFF0A080E),
    surface: Color(0xFF14101D),
    surfaceInset: Color(0xFF0E0B14),
    border: Color(0xFF2A203B),
    borderStrong: Color(0xFF42315C),
    textPrimary: Color(0xFFF5F2FA),
    textSecondary: Color(0xFF9C8FB3),
    textMuted: Color(0xFF5C526E),
    primary: Color(0xFF9333EA),
    primaryDim: Color(0xFF38115C),
    secondary: Color(0xFFF43F5E),
    secondaryDim: Color(0xFF571220),
    warning: Color(0xFF38BDF8),
    warningDim: Color(0xFF0E3C52),
    error: _defaultError,
  );

  static const List<EvaPalette> presets = [
    eva00Proto,
    eva00Blue,
    eva01,
    eva02,
    eva03,
    eva04,
    eva05,
    eva06,
    eva07,
    eva08,
    eva09,
    eva10,
    eva11,
    eva12,
    eva13,
  ];

  static EvaPalette byId(String id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return eva01;
  }

  @override
  EvaPalette copyWith({
    String? id,
    String? unitCode,
    String? name,
    String? subtitle,
    Color? bg,
    Color? surface,
    Color? surfaceInset,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? primaryDim,
    Color? secondary,
    Color? secondaryDim,
    Color? warning,
    Color? warningDim,
    Color? error,
  }) {
    return EvaPalette(
      id: id ?? this.id,
      unitCode: unitCode ?? this.unitCode,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceInset: surfaceInset ?? this.surfaceInset,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      primaryDim: primaryDim ?? this.primaryDim,
      secondary: secondary ?? this.secondary,
      secondaryDim: secondaryDim ?? this.secondaryDim,
      warning: warning ?? this.warning,
      warningDim: warningDim ?? this.warningDim,
      error: error ?? this.error,
    );
  }

  @override
  EvaPalette lerp(ThemeExtension<EvaPalette>? other, double t) {
    if (other is! EvaPalette) return this;
    return EvaPalette(
      id: t < 0.5 ? id : other.id,
      unitCode: t < 0.5 ? unitCode : other.unitCode,
      name: t < 0.5 ? name : other.name,
      subtitle: t < 0.5 ? subtitle : other.subtitle,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceInset: Color.lerp(surfaceInset, other.surfaceInset, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDim: Color.lerp(primaryDim, other.primaryDim, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryDim: Color.lerp(secondaryDim, other.secondaryDim, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningDim: Color.lerp(warningDim, other.warningDim, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension EvaThemeContext on BuildContext {
  EvaPalette get eva => Theme.of(this).extension<EvaPalette>() ?? EvaPalette.eva01;
}
