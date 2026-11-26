import 'package:flutter/material.dart';
import '../../services/native_audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'album_artwork.dart';

/// Single standardized list item used across All Tracks, Folders, Albums, and Queue.
class TrackTile extends StatelessWidget {
  final AudioTrack track;
  final bool isSelected;
  final VoidCallback onTap;

  const TrackTile({
    super.key,
    required this.track,
    this.isSelected = false,
    required this.onTap,
  });

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot + 1 < path.length) {
      return path.substring(dot + 1).toUpperCase();
    }
    return 'PCM';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ext = track.extension;
    final isLossless = track.isLossless;
    final isDsd = track.isDsd;
    final badgeColor = isSelected
        ? colors.evaPurple
        : (isDsd
            ? colors.acidGreen
            : (isLossless ? colors.evaPurple : colors.textSecondary));

    return InkWell(
      onTap: onTap,
      splashColor: colors.evaPurpleDim.withOpacity(0.3),
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? colors.evaPurpleDim.withOpacity(0.2) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? colors.evaPurple : Colors.transparent,
              width: 3.0,
            ),
            bottom: BorderSide(
              color: colors.border,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Track artwork or extension badge
            if (track.artworkPath.isNotEmpty)
              AlbumArtwork(
                imagePath: track.artworkPath,
                size: 44,
                borderRadius: 6,
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surfaceInset,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? colors.evaPurple : badgeColor.withOpacity(0.5),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ext,
                      style: AppTypography.telemetrySmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? colors.evaPurple : badgeColor,
                      ),
                    ),
                    if (isLossless || isDsd) ...[
                      const SizedBox(height: 1),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDsd ? colors.acidGreen : colors.evaPurple,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(width: AppSpacing.md),

            // Title & Artist with Audiophile Quality Tag
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isDsd || isLossless) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: isDsd
                                ? colors.acidGreen.withOpacity(0.15)
                                : colors.evaPurple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: isDsd
                                  ? colors.acidGreen.withOpacity(0.6)
                                  : colors.evaPurple.withOpacity(0.6),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            isDsd ? 'DSD' : 'LOSSLESS',
                            style: AppTypography.telemetrySmall.copyWith(
                              fontSize: 8,
                              color: isDsd ? colors.acidGreen : colors.evaPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.trackTitle.copyWith(
                            color: isSelected ? colors.evaPurple : colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${track.artist} • ${track.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.trackArtist,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Duration & File Size
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(track.durationMs),
                  style: AppTypography.telemetrySmall.copyWith(
                    color: isSelected ? colors.textPrimary : colors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (track.formattedSize.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    track.formattedSize,
                    style: AppTypography.telemetrySmall.copyWith(
                      fontSize: 8.5,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
