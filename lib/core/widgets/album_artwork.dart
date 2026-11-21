import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Cached local album artwork loader with configurable square/circular crop
/// and terminal fallback icon.
class AlbumArtwork extends StatelessWidget {
  final String? imagePath;
  final double size;
  final bool isCircle;
  final double borderRadius;

  const AlbumArtwork({
    super.key,
    this.imagePath,
    this.size = 48.0,
    this.isCircle = false,
    this.borderRadius = AppSpacing.radiusButton,
  });

  @override
  Widget build(BuildContext context) {
    final hasValidFile = imagePath != null &&
        imagePath!.isNotEmpty &&
        File(imagePath!).existsSync();

    final shape = isCircle ? BoxShape.circle : BoxShape.rectangle;
    final radius = isCircle ? null : BorderRadius.circular(borderRadius);

    Widget imageWidget;
    if (hasValidFile) {
      imageWidget = Image.file(
        File(imagePath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else {
      imageWidget = _buildFallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.border,
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  Widget _buildFallback() {
    return Container(
      color: AppColors.surfaceInset,
      child: Center(
        child: Icon(
          Icons.graphic_eq,
          size: size * 0.5,
          color: AppColors.evaPurple,
        ),
      ),
    );
  }
}
