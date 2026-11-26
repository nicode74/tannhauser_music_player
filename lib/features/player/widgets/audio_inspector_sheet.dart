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
      backgroundColor: AppColors.of(context).surface,
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
                color: AppColors.of(context).borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.analytics_outlined, color: AppColors.of(context).acidGreen, size: 20),
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
                            color: AppColors.of(context).textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildRow(context, 'Audio Format', ext),
                        _buildRow(context, 
                          'Kategori Audio',
                          isDsd
                              ? 'DSD (Direct Stream Digital)'
                              : (isLossless ? 'Hi-Res Lossless Audio' : 'Standard Audio (Lossy)'),
                        ),
                        _buildRow(context, 
                          'Sample Rate',
                          sampleRate > 0 ? '$sampleRate Hz (${(sampleRate / 1000).toStringAsFixed(1)} kHz)' : '-- Hz',
                        ),
                        _buildRow(context, 'Bit Depth', bitDepth > 0 ? '$bitDepth-bit Linear PCM' : '-- bit'),
                        _buildRow(context, 'Channels', channels == 2 ? 'Stereo (Left / Right)' : '$channels Channels'),
                        _buildRow(context, 
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
                            color: AppColors.of(context).textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildRow(context, 'Perangkat Output', playerState.usbDeviceName),
                        _buildRow(context, 'Protokol USB', isUsb ? 'USB Audio Class 2.0 (UAC2)' : 'No USB DAC Attached'),
                        _buildRow(context, 'Android AudioFlinger', 'BYPASS TOTAL (libusb File Descriptor)'),
                        _buildRow(context, 'Isochronous Endpoint', isUsb ? 'Asynchronous Isochronous Stream' : 'Idle'),
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
                              color: AppColors.of(context).textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildRow(context, 'Judul', track.title),
                          _buildRow(context, 'Artis', track.artist),
                          _buildRow(context, 'Album', track.album),
                          if (track.formattedSize.isNotEmpty) _buildRow(context, 'Ukuran File', track.formattedSize),
                          _buildRow(context, 'Folder', track.folderName),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Path Lengkap:',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.of(context).textMuted),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            track.path,
                            style: AppTypography.telemetrySmall.copyWith(
                              fontSize: 9.5,
                              color: AppColors.of(context).textSecondary,
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

  Widget _buildRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.of(context).textMuted)),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.telemetrySmall.copyWith(
                color: AppColors.of(context).textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
