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
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final activeLedColor = ledColor ?? (isActive ? colors.acidGreen : colors.textMuted);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppSpacing.borderButton,
        splashColor: colors.evaPurpleDim.withOpacity(0.4),
        highlightColor: Colors.transparent,
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: colors.surfaceInset,
            borderRadius: AppSpacing.borderButton,
            border: Border.all(
              color: isActive ? colors.borderStrong : colors.border,
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top LED indicator dot (6x3px)
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
              const SizedBox(height: 4),
              if (child != null)
                child!
              else if (icon != null && label != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isActive ? colors.textPrimary : colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive ? colors.textPrimary : colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              else if (icon != null)
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? colors.textPrimary : colors.textSecondary,
                )
              else if (label != null)
                Text(
                  label!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
