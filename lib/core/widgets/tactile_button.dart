import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Flat/inset rectangular tactile button with top-center LED status indicator dot.
class TactileButton extends StatelessWidget {
  final Widget? child;
  final IconData? icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? ledColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const TactileButton({
    super.key,
    this.child,
    this.icon,
    this.label,
    this.onPressed,
    this.isActive = false,
    this.ledColor,
    this.width,
    this.height = 48.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final activeLedColor = ledColor ?? (isActive ? AppColors.acidGreen : AppColors.textMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppSpacing.borderButton,
        splashColor: AppColors.evaPurpleDim.withOpacity(0.4),
        highlightColor: Colors.transparent,
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surfaceInset,
            borderRadius: AppSpacing.borderButton,
            border: Border.all(
              color: isActive ? AppColors.borderStrong : AppColors.border,
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top LED indicator dot (4x3px)
              Container(
                width: 6,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1.5),
                  color: activeLedColor,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: activeLedColor.withOpacity(0.6),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              if (child != null)
                child!
              else if (icon != null)
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                )
              else if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
