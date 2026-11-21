import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum StatusPillType {
  bitPerfect,
  dspActive,
  noDac,
  standby,
  custom,
}

/// Compact monospace terminal status badge with semantic terminal colors.
class StatusPill extends StatelessWidget {
  final String label;
  final StatusPillType type;
  final Color? customColor;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    this.type = StatusPillType.standby,
    this.customColor,
    this.icon,
  });

  factory StatusPill.bitPerfect({String label = '[ 01 / SYNC: BIT-PERFECT ]'}) {
    return StatusPill(
      label: label,
      type: StatusPillType.bitPerfect,
      icon: Icons.check_circle_outline,
    );
  }

  factory StatusPill.dspActive({String label = '[ 01 / SYNC: DSP 64-BIT ]'}) {
    return StatusPill(
      label: label,
      type: StatusPillType.dspActive,
      icon: Icons.tune,
    );
  }

  factory StatusPill.noDac({String label = '[ ⚡ NO DAC DETECTED ]'}) {
    return StatusPill(
      label: label,
      type: StatusPillType.noDac,
      icon: Icons.warning_amber_rounded,
    );
  }

  factory StatusPill.standby({String label = '[ STDBY ]'}) {
    return StatusPill(
      label: label,
      type: StatusPillType.standby,
      icon: Icons.radio_button_unchecked,
    );
  }

  Color get _color {
    if (customColor != null) return customColor!;
    switch (type) {
      case StatusPillType.bitPerfect:
        return AppColors.acidGreen;
      case StatusPillType.dspActive:
        return AppColors.evaPurple;
      case StatusPillType.noDac:
        return AppColors.hazardOrange;
      case StatusPillType.standby:
      case StatusPillType.custom:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppSpacing.borderBadge,
        border: Border.all(
          color: color.withOpacity(0.6),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTypography.statusPill.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
