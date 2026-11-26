import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Base container for EVA-01 Tactile Audio Terminal.
/// Supports inset mode (surfaceInset) and flat elevated mode (surface).
class HardwarePanel extends StatelessWidget {
  final Widget child;
  final bool inset;
  final bool active;
  final bool hasHazardBorder;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const HardwarePanel({
    super.key,
    required this.child,
    this.inset = false,
    this.active = false,
    this.hasHazardBorder = false,
    this.padding = AppSpacing.edgeMd,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final borderColor = hasHazardBorder
        ? colors.hazardOrange
        : (active ? colors.borderStrong : colors.border);

    final backgroundColor = inset ? colors.surfaceInset : colors.surface;

    Widget panel = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppSpacing.borderPanel,
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      panel = InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderPanel,
        splashColor: colors.evaPurpleDim.withOpacity(0.3),
        highlightColor: Colors.transparent,
        child: panel,
      );
    }

    return panel;
  }
}
