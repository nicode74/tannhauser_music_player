import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/album_artwork.dart';
import '../../core/widgets/hardware_panel.dart';
import '../../core/widgets/tactile_button.dart';
import '../../core/widgets/track_tile.dart';
import '../../services/native_audio_service.dart';
import '../player/controllers/player_state.dart';
import 'widgets/mini_player_bar.dart';

/// Unified Drill-Down Screen for Folders & Albums (Lean 3+3 Step 2)
class CollectionDetailPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<AudioTrack> tracks;
  final bool isAlbum;
  final PlayerState playerState;
  final VoidCallback onOpenNowPlaying;

  const CollectionDetailPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tracks,
    this.isAlbum = false,
    required this.playerState,
    required this.onOpenNowPlaying,
  });

  String _formatTotalDuration(int totalMs) {
    final totalSeconds = totalMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    if (hours > 0) {
      return '$hours j $remMinutes m';
    }
    return '$minutes mnt';
  }

  void _playAll() {
    if (tracks.isEmpty) return;
    playerState.setQueue(tracks, startIndex: 0);
  }

  void _shufflePlay() {
    if (tracks.isEmpty) return;
    final randomIndex = Random().nextInt(tracks.length);
    playerState.setQueue(tracks, startIndex: randomIndex);
    if (!playerState.isShuffle) {
      playerState.toggleShuffle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDurationMs = tracks.fold<int>(0, (sum, t) => sum + t.durationMs);

    return ListenableBuilder(
      listenable: playerState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isAlbum ? 'ALBUM DETAIL' : 'FOLDER DETAIL'),
          ),
          body: Column(
            children: [
              // 1. Collection Header Panel
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: HardwarePanel(
                  padding: AppSpacing.edgeMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isAlbum)
                            const AlbumArtwork(size: 64, borderRadius: 8)
                          else
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceInset,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.folder,
                                color: AppColors.evaPurple,
                                size: 36,
                              ),
                            ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.trackTitle.copyWith(fontSize: 16),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.trackArtist,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${tracks.length} trek • ${_formatTotalDuration(totalDurationMs)}',
                                  style: AppTypography.telemetrySmall.copyWith(
                                    color: AppColors.evaPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Tactile Action Row (PLAY ALL & SHUFFLE)
                      Row(
                        children: [
                          Expanded(
                            child: TactileButton(
                              height: 42,
                              icon: Icons.play_arrow,
                              label: 'PUTAR SEMUA',
                              isActive: true,
                              ledColor: AppColors.acidGreen,
                              onPressed: _playAll,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TactileButton(
                              height: 42,
                              icon: Icons.shuffle,
                              label: 'ACAK',
                              onPressed: _shufflePlay,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Tracks List
              Expanded(
                child: tracks.isEmpty
                    ? Center(
                        child: Text(
                          'Folder ini kosong.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          final isSelected = playerState.selectedTrack?.path == track.path;

                          return TrackTile(
                            track: track,
                            isSelected: isSelected,
                            onTap: () {
                              playerState.setQueue(tracks, startIndex: index);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          bottomNavigationBar: MiniPlayerBar(
            playerState: playerState,
            onTap: onOpenNowPlaying,
          ),
        );
      },
    );
  }
}
