import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/hardware_panel.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/tactile_button.dart';
import '../../peq/controllers/peq_state.dart';
import '../controllers/player_state.dart';

/// Audiophile Audio Specification & Stream Telemetry Inspector
class AudioInspectorSheet extends StatelessWidget {
  final PlayerState playerState;
  final PeqState? peqState;

  const AudioInspectorSheet({
    super.key,
    required this.playerState,
    this.peqState,
  });

  static Future<void> show(BuildContext context, PlayerState playerState, {PeqState? peqState}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusPanel)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: AudioInspectorSheet(
          playerState: playerState,
          peqState: peqState,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final track = playerState.selectedTrack;
    final info = playerState.playbackInfo;
    final isUsb = playerState.isUsbConnected;
    final isPeq = peqState?.isEnabled ?? false;

    final sampleRate = info?.sampleRate ?? 0;
    final bitDepth = info?.bitDepth ?? 0;
    final channels = info?.channels ?? 2;
    final ext = track?.extension ?? 'PCM';
    final isLossless = track?.isLossless ?? false;
    final isDsd = track?.isDsd ?? false;

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
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: AppColors.acidGreen, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'AUDIO SPEC INSPECTOR',
                      style: AppTypography.header.copyWith(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill(
                    label: isPeq ? '[ DSP 64-BIT ]' : '[ BIT-PERFECT ]',
                    type: isPeq ? StatusPillType.dspActive : StatusPillType.bitPerfect,
                  ),
                ],
              ),
            ),
            const Divider(),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: AppSpacing.screenPadding,
                children: [
                  // 1. Audio Stream Spec Card
                  HardwarePanel(
                    inset: true,
                    padding: AppSpacing.edgeMd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STREAM TELEMETRY // REALTIME',
                          style: AppTypography.telemetrySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildRow('Audio Format', ext),
                        _buildRow(
                          'Kategori Audio',
                          isDsd
                              ? 'DSD (Direct Stream Digital)'
                              : (isLossless ? 'Hi-Res Lossless Audio' : 'Standard Audio (Lossy)'),
                        ),
                        _buildRow(
                          'Sample Rate',
                          sampleRate > 0 ? '$sampleRate Hz (${(sampleRate / 1000).toStringAsFixed(1)} kHz)' : '-- Hz',
                        ),
                        _buildRow('Bit Depth', bitDepth > 0 ? '$bitDepth-bit Linear PCM' : '-- bit'),
                        _buildRow('Channels', channels == 2 ? 'Stereo (Left / Right)' : '$channels Channels'),
                        _buildRow(
                          'Prosesor Audio',
                          isPeq
                              ? '64-bit RBJ Biquad TDF-II Cascade (Active DSP)'
                              : 'Bypass Murni (Zero Mixer & Zero Resample)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Hardware Output Path Card
                  HardwarePanel(
                    padding: AppSpacing.edgeMd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HARDWARE TRANSPORT PATH',
                          style: AppTypography.telemetrySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildRow('Perangkat Output', playerState.usbDeviceName),
                        _buildRow('Protokol USB', isUsb ? 'USB Audio Class 2.0 (UAC2)' : 'No USB DAC Attached'),
                        _buildRow('Android AudioFlinger', 'BYPASS TOTAL (libusb File Descriptor)'),
                        _buildRow('Isochronous Endpoint', isUsb ? 'Asynchronous Isochronous Stream' : 'Idle'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Local File Details Card
                  if (track != null) ...[
                    HardwarePanel(
                      inset: true,
                      padding: AppSpacing.edgeMd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RINCIAN FILE LOKAL',
                            style: AppTypography.telemetrySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildRow('Judul', track.title),
                          _buildRow('Artis', track.artist),
                          _buildRow('Album', track.album),
                          if (track.formattedSize.isNotEmpty) _buildRow('Ukuran File', track.formattedSize),
                          _buildRow('Folder', track.folderName),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Path Lengkap:',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            track.path,
                            style: AppTypography.telemetrySmall.copyWith(
                              fontSize: 9.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.telemetrySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
