import 'package:flutter/material.dart' hide RepeatMode;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/hardware_panel.dart';
import '../../core/widgets/tactile_button.dart';
import '../../core/widgets/track_tile.dart';
import 'controllers/player_state.dart';

/// Interactive Drag-to-Reorder Playback Queue Modal Sheet (Lean 3+3 Step 5)
class QueueSheet extends StatelessWidget {
  final PlayerState playerState;

  const QueueSheet({
    super.key,
    required this.playerState,
  });

  static Future<void> show(BuildContext context, PlayerState playerState) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusPanel)),
      ),
      builder: (_) => QueueSheet(playerState: playerState),
    );
  }

  IconData _repeatIcon(PlaybackRepeatMode mode) {
    switch (mode) {
      case PlaybackRepeatMode.off:
        return Icons.repeat;
      case PlaybackRepeatMode.all:
        return Icons.repeat_on;
      case PlaybackRepeatMode.one:
        return Icons.repeat_one_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerState,
      builder: (context, _) {
        final queue = playerState.queue;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                // Top drag pill
                Container(
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.queue_music, color: AppColors.evaPurple, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'UP NEXT // QUEUE (${queue.length})',
                            style: AppTypography.header.copyWith(fontSize: 14),
                          ),
                        ],
                      ),

                      // Actions: Shuffle & Repeat
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color: playerState.isShuffle ? AppColors.evaPurple : AppColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: 'Acak Antrean',
                            onPressed: playerState.toggleShuffle,
                          ),
                          IconButton(
                            icon: Icon(
                              _repeatIcon(playerState.repeatMode),
                              color: playerState.repeatMode != PlaybackRepeatMode.off
                                  ? AppColors.acidGreen
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: 'Mode Ulang',
                            onPressed: playerState.toggleRepeatMode,
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear_all, color: AppColors.textSecondary, size: 20),
                            tooltip: 'Kosongkan Antrean',
                            onPressed: queue.isNotEmpty ? playerState.clearQueue : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Reorderable Queue List
                Expanded(
                  child: queue.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.queue_music, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Antrean putar kosong.',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          scrollController: scrollController,
                          itemCount: queue.length,
                          onReorder: playerState.reorderQueue,
                          itemBuilder: (context, index) {
                            final track = queue[index];
                            final isSelected = playerState.selectedTrack?.path == track.path;

                            return Dismissible(
                              key: ValueKey('${track.path}_$index'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: AppColors.errorRed.withOpacity(0.3),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: AppColors.errorRed),
                              ),
                              onDismissed: (_) {
                                playerState.removeFromQueue(index);
                              },
                              child: Row(
                                key: ValueKey('row_${track.path}_$index'),
                                children: [
                                  Expanded(
                                    child: TrackTile(
                                      track: track,
                                      isSelected: isSelected,
                                      onTap: () {
                                        playerState.loadFile(track).then((_) {
                                          playerState.play();
                                        });
                                      },
                                    ),
                                  ),
                                  // Drag handle reorder icon
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                      child: Icon(
                                        Icons.drag_handle,
                                        color: AppColors.textMuted,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
