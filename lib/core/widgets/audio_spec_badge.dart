import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Monospace badge displaying technical audio telemetry:
/// Codec, sample rate (kHz), bit depth, and bitrate.
class AudioSpecBadge extends StatelessWidget {
  final String codec;
  final int sampleRate;
  final int bitDepth;
  final int bitRateKbps;
  final bool isDspActive;

  const AudioSpecBadge({
    super.key,
    required this.codec,
    required this.sampleRate,
    required this.bitDepth,
    this.bitRateKbps = 0,
    this.isDspActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sampleRateStr = sampleRate > 0
        ? '${(sampleRate / 1000).toStringAsFixed(1)} kHz'
        : '-- kHz';
    final bitDepthStr = bitDepth > 0 ? '$bitDepth-bit' : '-- bit';
    final codecStr = codec.isNotEmpty ? codec.toUpperCase() : 'PCM';

    final text = bitRateKbps > 0
        ? '$codecStr • $sampleRateStr / $bitDepthStr • $bitRateKbps kbps'
        : '$codecStr • $sampleRateStr / $bitDepthStr';

    final accentColor = isDspActive ? colors.evaPurple : colors.acidGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceInset,
        borderRadius: AppSpacing.borderBadge,
        border: Border.all(
          color: colors.border,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.telemetrySmall.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
