import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../player/controllers/player_state.dart';

class ScanTerminalSheet extends StatelessWidget {
  final PlayerState playerState;

  const ScanTerminalSheet({
    super.key,
    required this.playerState,
  });

  static Future<void> show(BuildContext context, PlayerState playerState) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: !playerState.isScanning,
      enableDrag: !playerState.isScanning,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusPanel)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: ScanTerminalSheet(playerState: playerState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: playerState,
      builder: (context, _) {
        final isScanning = playerState.isScanning;
        final currentDir = playerState.scanCurrentDir;
        final count = playerState.scanCount;

        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Header
              Row(
                children: [
                  Icon(
                    isScanning ? Icons.radar : Icons.check_circle_outline,
                    color: isScanning ? AppColors.acidGreen : AppColors.evaPurple,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      isScanning ? 'NERV STORAGE SCANNER // LIVE TELEMETRY' : 'PEMINDAIAN SELESAI',
                      style: AppTypography.header.copyWith(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceInset,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isScanning ? AppColors.acidGreen : AppColors.evaPurple,
                      ),
                    ),
                    child: Text(
                      isScanning ? 'ACTIVE' : 'IDLE',
                      style: AppTypography.statusPill.copyWith(
                        color: isScanning ? AppColors.acidGreen : AppColors.evaPurple,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),

              // Monospace Terminal Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '// PROTOCOL: DIRECT FILESYSTEM TRAVERSAL',
                      style: AppTypography.codeSnippet.copyWith(color: AppColors.acidGreen, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '// C++ FAST PROBER: AVFORMAT_FIND_STREAM_INFO',
                      style: AppTypography.codeSnippet.copyWith(color: AppColors.textMuted, fontSize: 10),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'STATUS: ${isScanning ? "MEMINDAI DIREKTORI..." : "SELESAI"}',
                      style: AppTypography.codeSnippet.copyWith(
                        color: isScanning ? AppColors.acidGreen : AppColors.evaPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TREK DITEMUKAN: $count',
                      style: AppTypography.codeSnippet.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'PATH SAAT INI:',
                      style: AppTypography.codeSnippet.copyWith(color: AppColors.textMuted, fontSize: 10),
                    ),
                    Text(
                      currentDir.isNotEmpty ? currentDir : '---',
                      style: AppTypography.codeSnippet.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              Row(
                children: [
                  if (isScanning)
                    Expanded(
                      child: TactileButton(
                        label: 'BATALKAN',
                        icon: Icons.cancel,
                        onPressed: () {
                          playerState.stopScan();
                          Navigator.of(context).pop();
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: TactileButton(
                        label: 'PINDAI ULANG',
                        icon: Icons.refresh,
                        onPressed: () {
                          playerState.scanStorage(rescan: true);
                        },
                      ),
                    ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.evaPurple,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('TUTUP'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
