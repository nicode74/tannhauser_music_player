import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/audio_spec_badge.dart';
import '../../core/widgets/hardware_panel.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/tactile_button.dart';
import '../peq/controllers/peq_state.dart';
import '../peq/peq_editor_sheet.dart';
import '../system/system_console_sheet.dart';
import 'controllers/player_state.dart';
import 'queue_sheet.dart';
import 'widgets/disc_seek_wheel.dart';

/// Full-Screen Playback Console: NowPlayingPage (Lean 3+3 Step 3)
class NowPlayingPage extends StatefulWidget {
  final PlayerState playerState;
  final PeqState? peqState;
  final VoidCallback? onOpenPeq;
  final VoidCallback? onOpenQueue;
  final VoidCallback? onOpenSystemConsole;

  const NowPlayingPage({
    super.key,
    required this.playerState,
    this.peqState,
    this.onOpenPeq,
    this.onOpenQueue,
    this.onOpenSystemConsole,
  });

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  PlayerState get _playerState => widget.playerState;
  late final PeqState _peqState;

  @override
  void initState() {
    super.initState();
    _peqState = widget.peqState ?? PeqState();
  }

  void _handleOpenPeq() {
    if (widget.onOpenPeq != null) {
      widget.onOpenPeq!();
    } else {
      PeqEditorSheet.show(context, _peqState);
    }
  }

  void _handleOpenQueue() {
    if (widget.onOpenQueue != null) {
      widget.onOpenQueue!();
    } else {
      QueueSheet.show(context, _playerState);
    }
  }

  void _handleOpenSystemConsole() {
    if (widget.onOpenSystemConsole != null) {
      widget.onOpenSystemConsole!();
    } else {
      SystemConsoleSheet.show(context, _playerState);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _playerState,
      builder: (context, _) {
        final track = _playerState.selectedTrack;
        final isPlaying = _playerState.isPlaying;
        final isUsbConnected = _playerState.isUsbConnected;
        final playbackInfo = _playerState.playbackInfo;
        final sampleRate = playbackInfo?.sampleRate ?? 0;
        final bitDepth = playbackInfo?.bitDepth ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('NOW PLAYING // UNIT-01'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_input_component, size: 20),
                tooltip: 'Konsol Sistem & Hardware DAC',
                onPressed: _handleOpenSystemConsole,
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Telemetry Bar
                  _buildTopTelemetryBar(isUsbConnected),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Audio Spec Badge & Sync Pill
                  _buildSpecRow(sampleRate, bitDepth, isUsbConnected),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Track Info Block with vertical accent
                  _buildTrackInfoBlock(track),
                  const SizedBox(height: AppSpacing.lg),

                  // 4. Center Rotary Jog-Wheel Scrubber
                  Center(
                    child: DiscSeekWheel(
                      size: 220,
                      positionMs: playbackInfo?.positionMs ?? 0,
                      durationMs: playbackInfo?.totalDurationMs ?? 0,
                      isPlaying: isPlaying,
                      isUsbConnected: isUsbConnected,
                      artworkPath: null,
                      onSeekCommit: (seekMs) {
                        _playerState.seek(seekMs);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 5. Lower-Mid Parametric EQ Mini Preview Panel
                  _buildMiniPeqPreviewPanel(),
                  const SizedBox(height: AppSpacing.lg),

                  // 6. Tactile Transport Deck
                  _buildTransportDeck(isPlaying),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopTelemetryBar(bool isUsbConnected) {
    return InkWell(
      onTap: _handleOpenSystemConsole,
      borderRadius: AppSpacing.borderPanel,
      child: HardwarePanel(
        hasHazardBorder: !isUsbConnected,
        padding: AppSpacing.edgeMd,
        child: Row(
          children: [
            Icon(
              isUsbConnected ? Icons.usb : Icons.usb_off,
              color: isUsbConnected ? AppColors.acidGreen : AppColors.hazardOrange,
              size: 26,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUsbConnected ? 'USB DAC CONNECTED' : 'NO DAC DETECTED',
                    style: AppTypography.statusPill.copyWith(
                      color: isUsbConnected ? AppColors.acidGreen : AppColors.hazardOrange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _playerState.usbDeviceName,
                    style: AppTypography.trackArtist.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusPill(
              label: isUsbConnected ? 'BYPASS ACTIVE' : 'UNSYNCED',
              type: isUsbConnected ? StatusPillType.bitPerfect : StatusPillType.noDac,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(int sampleRate, int bitDepth, bool isUsbConnected) {
    return ListenableBuilder(
      listenable: _peqState,
      builder: (context, _) {
        final isPeqActive = _peqState.isEnabled;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AudioSpecBadge(
              codec: 'FLAC',
              sampleRate: sampleRate,
              bitDepth: bitDepth,
              isDspActive: isPeqActive,
            ),
            StatusPill(
              label: !isUsbConnected
                  ? '[ STDBY ]'
                  : (isPeqActive ? '[ 01 / SYNC: DSP 64-BIT ]' : '[ 01 / SYNC: BIT-PERFECT ]'),
              type: !isUsbConnected
                  ? StatusPillType.standby
                  : (isPeqActive ? StatusPillType.dspActive : StatusPillType.bitPerfect),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackInfoBlock(dynamic track) {
    final title = track?.title ?? 'Tidak ada trek aktif';
    final artist = track != null ? '${track.artist} • ${track.album}' : 'Pilih trek dari pustaka';

    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.evaPurple, width: 3.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.trackTitle.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.trackArtist,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPeqPreviewPanel() {
    return ListenableBuilder(
      listenable: _peqState,
      builder: (context, _) {
        final isPeqActive = _peqState.isEnabled;
        return HardwarePanel(
          inset: true,
          padding: AppSpacing.edgeMd,
          onTap: _handleOpenPeq,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 14,
                        color: isPeqActive ? AppColors.acidGreen : AppColors.evaPurple,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '64-BIT PARAMETRIC EQ (PEQ)',
                        style: AppTypography.telemetrySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPeqActive ? AppColors.acidGreen.withOpacity(0.15) : AppColors.surface,
                      borderRadius: AppSpacing.borderBadge,
                      border: Border.all(
                        color: isPeqActive ? AppColors.acidGreen : AppColors.border,
                      ),
                    ),
                    child: Text(
                      isPeqActive ? 'ACTIVE (DSP)' : 'BYPASS',
                      style: AppTypography.telemetrySmall.copyWith(
                        color: isPeqActive ? AppColors.acidGreen : AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: isPeqActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Mini Frequency Response Visualizer Slot
              Container(
                height: 48,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: CustomPaint(
                  painter: _MiniPeqCurvePainter(peqState: _peqState),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('20 Hz', style: AppTypography.telemetrySmall.copyWith(color: AppColors.textMuted, fontSize: 9)),
                  Text('1 kHz', style: AppTypography.telemetrySmall.copyWith(color: AppColors.textMuted, fontSize: 9)),
                  Text('20 kHz', style: AppTypography.telemetrySmall.copyWith(color: AppColors.textMuted, fontSize: 9)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransportDeck(bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TactileButton(
          icon: Icons.skip_previous,
          width: 50,
          height: 48,
          onPressed: _playerState.previous,
        ),
        TactileButton(
          icon: Icons.stop,
          width: 50,
          height: 48,
          onPressed: _playerState.stop,
        ),
        TactileButton(
          icon: isPlaying ? Icons.pause : Icons.play_arrow,
          width: 68,
          height: 52,
          isActive: isPlaying,
          ledColor: AppColors.acidGreen,
          onPressed: _playerState.togglePlayPause,
        ),
        TactileButton(
          icon: Icons.skip_next,
          width: 50,
          height: 48,
          onPressed: _playerState.next,
        ),
        TactileButton(
          icon: Icons.queue_music,
          width: 50,
          height: 48,
          onPressed: _handleOpenQueue,
        ),
        TactileButton(
          icon: Icons.tune,
          width: 50,
          height: 48,
          onPressed: _handleOpenPeq,
        ),
      ],
    );
  }
}

class _MiniPeqCurvePainter extends CustomPainter {
  final PeqState peqState;

  _MiniPeqCurvePainter({required this.peqState});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), gridPaint);

    final points = peqState.computeResponseCurve(points: 60);
    final path = Path();
    final w = size.width;
    final h = size.height;

    for (int i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * w;
      // Map gain (-12dB .. +12dB) to y (h .. 0)
      final gain = points[i].dy;
      final y = (h / 2) - (gain / 12.0) * (h / 2.2);
      final clampedY = y.clamp(2.0, h - 2.0);
      if (i == 0) {
        path.moveTo(x, clampedY);
      } else {
        path.lineTo(x, clampedY);
      }
    }

    final curvePaint = Paint()
      ..color = peqState.isEnabled ? AppColors.acidGreen : AppColors.textMuted
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniPeqCurvePainter oldDelegate) => true;
}
