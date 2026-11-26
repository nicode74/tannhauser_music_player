import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/hardware_panel.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/tactile_button.dart';
import '../controllers/player_state.dart';

/// EVA-01 Sleep Timer Modal Sheet
class SleepTimerSheet extends StatelessWidget {
  final PlayerState playerState;

  const SleepTimerSheet({
    super.key,
    required this.playerState,
  });

  static Future<void> show(BuildContext context, PlayerState playerState) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusPanel)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: SleepTimerSheet(playerState: playerState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerState,
      builder: (context, _) {
        final isActive = playerState.isSleepTimerActive;

        return Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag pill
              Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.of(context).borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.snooze, color: AppColors.of(context).evaPurple, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'SLEEP TIMER // PROTOCOL',
                        style: AppTypography.header.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusPill(
                      label: isActive ? 'ACTIVE' : 'OFF',
                      type: isActive ? StatusPillType.dspActive : StatusPillType.standby,
                    ),
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.md),

              // Active Countdown Telemetry Card
              if (isActive) ...[
                HardwarePanel(
                  inset: true,
                  padding: AppSpacing.edgeMd,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.of(context).acidGreen,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WAKTU TERSISA SEBELUM PAUSE',
                              style: AppTypography.telemetrySmall.copyWith(
                                color: AppColors.of(context).textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              playerState.sleepTimeFormatted,
                              style: AppTypography.telemetryLarge.copyWith(
                                color: AppColors.of(context).acidGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TactileButton(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        label: 'BATALKAN',
                        onPressed: () {
                          playerState.cancelSleepTimer();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Preset Options Grid
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _buildTimerChip(context, 15, '15 MENIT'),
                  _buildTimerChip(context, 30, '30 MENIT'),
                  _buildTimerChip(context, 45, '45 MENIT'),
                  _buildTimerChip(context, 60, '60 MENIT'),
                  _buildTimerChip(context, 90, '90 MENIT'),
                  _buildSpecialChip(
                    context,
                    label: 'AKHIR TREK INI',
                    isSelected: playerState.sleepAtTrackEnd,
                    onTap: () {
                      playerState.setSleepAtTrackEnd(true);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Musik akan berhenti otomatis di akhir trek.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimerChip(BuildContext context, int minutes, String label) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 48) / 2,
      child: TactileButton(
        height: 44,
        label: label,
        onPressed: () {
          playerState.setSleepTimer(minutes);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sleep Timer diatur: $minutes menit.'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpecialChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TactileButton(
        height: 44,
        label: label,
        isActive: isSelected,
        ledColor: AppColors.of(context).acidGreen,
        onPressed: onTap,
      ),
    );
  }
}
