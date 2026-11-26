import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/album_artwork.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../player/controllers/player_state.dart';

/// Docked bottom mini player bar with hairline progress line,
/// tactile controls, and tap-to-open Now Playing console.
class MiniPlayerBar extends StatelessWidget {
  final PlayerState playerState;
  final VoidCallback onTap;

  const MiniPlayerBar({
    super.key,
    required this.playerState,
    required this.onTap,
  });

  String _formatExt(String path) {
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot + 1 < path.length) {
      return path.substring(dot + 1).toUpperCase();
    }
    return 'PCM';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final track = playerState.selectedTrack;
    if (track == null) return const SizedBox.shrink();

    final isPlaying = playerState.isPlaying;
    final playbackInfo = playerState.playbackInfo;
    final position = (playbackInfo?.positionMs ?? 0).toDouble();
    final duration = (playbackInfo?.totalDurationMs ?? 0).toDouble();
    final progress = duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final ext = _formatExt(track.path);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onTap,
          splashColor: colors.evaPurpleDim.withOpacity(0.3),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hairline 2px Progress Bar
              LinearProgressIndicator(
                value: progress,
                minHeight: 2.0,
                backgroundColor: colors.surfaceInset,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isPlaying ? colors.acidGreen : colors.evaPurple,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    // Album Artwork thumbnail
                    AlbumArtwork(
                      imagePath: track.artworkPath,
                      size: 40,
                      borderRadius: AppSpacing.radiusBadge,
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Title & Metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.trackTitle.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colors.surfaceInset,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Text(
                                  ext,
                                  style: AppTypography.telemetrySmall.copyWith(
                                    fontSize: 9,
                                    color: colors.evaPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.trackArtist.copyWith(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Tactile Transport Controls
                    TactileButton(
                      width: 44,
                      height: 40,
                      icon: isPlaying ? Icons.pause : Icons.play_arrow,
                      isActive: isPlaying,
                      ledColor: colors.acidGreen,
                      onPressed: playerState.togglePlayPause,
                    ),
                    const SizedBox(width: 6),
                    TactileButton(
                      width: 40,
                      height: 40,
                      icon: Icons.skip_next,
                      onPressed: playerState.next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
