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
    final ext = _extensionFromPath(track.path);

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.evaPurpleDim.withOpacity(0.3),
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.evaPurpleDim.withOpacity(0.2) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.evaPurple : Colors.transparent,
              width: 3.0,
            ),
            bottom: const BorderSide(
              color: AppColors.border,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Track extension badge / artwork
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surfaceInset,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? AppColors.evaPurple : AppColors.border,
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  ext,
                  style: AppTypography.telemetrySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.evaPurple : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.trackTitle.copyWith(
                      color: isSelected ? AppColors.evaPurple : AppColors.textPrimary,
                    ),
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

            // Duration
            Text(
              _formatDuration(track.durationMs),
              style: AppTypography.telemetrySmall.copyWith(
                color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
