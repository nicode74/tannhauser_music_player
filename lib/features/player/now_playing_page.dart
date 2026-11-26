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
import 'widgets/audio_inspector_sheet.dart';
import 'widgets/disc_seek_wheel.dart';
import 'widgets/sleep_timer_sheet.dart';

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
  bool _isScrubbing = false;

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
            title: Text('NOW PLAYING // ${AppColors.of(context).unitCode}'),
            actions: [
              IconButton(
                icon: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Icon(
                      Icons.snooze,
                      size: 20,
                      color: _playerState.isSleepTimerActive ? AppColors.of(context).acidGreen : AppColors.of(context).textPrimary,
                    ),
                    if (_playerState.isSleepTimerActive)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.of(context).acidGreen,
                        ),
                      ),
                  ],
                ),
                tooltip: _playerState.isSleepTimerActive
                    ? 'Sleep Timer: ${_playerState.sleepTimeFormatted}'
                    : 'Atur Sleep Timer',
                onPressed: () => SleepTimerSheet.show(context, _playerState),
              ),
              IconButton(
                icon: const Icon(Icons.settings_input_component, size: 20),
                tooltip: 'Konsol Sistem & Hardware DAC',
                onPressed: _handleOpenSystemConsole,
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: _isScrubbing
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Telemetry Bar
                  _buildTopTelemetryBar(isUsbConnected),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Audio Spec Badge & Sync Pill
                  _buildSpecRow(sampleRate, bitDepth, isUsbConnected, track),
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
                      artworkPath: track?.artworkPath,
                      onSeekStart: () {
                        setState(() {
                          _isScrubbing = true;
                        });
                      },
                      onSeekEnd: () {
                        setState(() {
                          _isScrubbing = false;
                        });
                      },
                      onSeekCommit: (seekMs) {
                        _playerState.seek(seekMs);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 5. Lower-Mid Parametric EQ Mini Preview Panel
                  _buildMiniPeqPreviewPanel(),
                  const SizedBox(height: AppSpacing.md),

                  // 5b. EVA-01 Master Volume Slider
                  _buildMasterVolumeSlider(),
                  const SizedBox(height: AppSpacing.lg),

                  // 6. Tactile Transport Deck
                  _buildTransportDeck(isPlaying),
                  const SizedBox(height: AppSpacing.xl),
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
              color: isUsbConnected ? AppColors.of(context).acidGreen : AppColors.of(context).hazardOrange,
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
                      color: isUsbConnected ? AppColors.of(context).acidGreen : AppColors.of(context).hazardOrange,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _playerState.usbDeviceName,
                    style: AppTypography.trackArtist.copyWith(
                      color: AppColors.of(context).textPrimary,
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

  Widget _buildSpecRow(int sampleRate, int bitDepth, bool isUsbConnected, dynamic track) {
    return ListenableBuilder(
      listenable: _peqState,
      builder: (context, _) {
        final isPeqActive = _peqState.isEnabled;
        final codec = track != null ? (track.extension as String) : 'FLAC';

        return Row(
          children: [
            Expanded(
              flex: 5,
              child: InkWell(
                borderRadius: AppSpacing.borderBadge,
                onTap: () => AudioInspectorSheet.show(context, _playerState, peqState: _peqState),
                child: AudioSpecBadge(
                  codec: codec,
                  sampleRate: sampleRate,
                  bitDepth: bitDepth,
                  isDspActive: isPeqActive,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              flex: 4,
              child: StatusPill(
                label: !isUsbConnected
                    ? '[ STDBY ]'
                    : (isPeqActive ? '[ DSP 64-BIT ]' : '[ BIT-PERFECT ]'),
                type: !isUsbConnected
                    ? StatusPillType.standby
                    : (isPeqActive ? StatusPillType.dspActive : StatusPillType.bitPerfect),
              ),
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
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppColors.of(context).evaPurple, width: 3.5),
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
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune,
                          size: 14,
                          color: isPeqActive ? AppColors.of(context).acidGreen : AppColors.of(context).evaPurple,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            '64-BIT PARAMETRIC EQ',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.telemetrySmall.copyWith(
                              color: AppColors.of(context).textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPeqActive ? AppColors.of(context).acidGreen.withOpacity(0.15) : AppColors.of(context).surface,
                      borderRadius: AppSpacing.borderBadge,
                      border: Border.all(
                        color: isPeqActive ? AppColors.of(context).acidGreen : AppColors.of(context).border,
                      ),
                    ),
                    child: Text(
                      isPeqActive ? 'ACTIVE (DSP)' : 'BYPASS',
                      style: AppTypography.telemetrySmall.copyWith(
                        color: isPeqActive ? AppColors.of(context).acidGreen : AppColors.of(context).textMuted,
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
                  color: AppColors.of(context).bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.of(context).border, width: 0.8),
                ),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _MiniPeqCurvePainter(
                      peqState: _peqState,
                      colors: AppColors.of(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('20 Hz', style: AppTypography.telemetrySmall.copyWith(color: AppColors.of(context).textMuted, fontSize: 9)),
                  Text('1 kHz', style: AppTypography.telemetrySmall.copyWith(color: AppColors.of(context).textMuted, fontSize: 9)),
                  Text('20 kHz', style: AppTypography.telemetrySmall.copyWith(color: AppColors.of(context).textMuted, fontSize: 9)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMasterVolumeSlider() {
    final vol = _playerState.volume;
    final volPercent = (vol * 100).toInt();

    return HardwarePanel(
      inset: true,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            vol == 0
                ? Icons.volume_off
                : (vol < 0.5 ? Icons.volume_down : Icons.volume_up),
            size: 18,
            color: vol > 0.0 ? AppColors.of(context).acidGreen : AppColors.of(context).textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'VOL',
            style: AppTypography.telemetrySmall.copyWith(
              color: AppColors.of(context).textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.of(context).acidGreen,
                inactiveTrackColor: AppColors.of(context).surface,
                thumbColor: AppColors.of(context).acidGreen,
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              ),
              child: Slider(
                value: vol,
                min: 0.0,
                max: 1.0,
                onChanged: (val) {
                  _playerState.setVolume(val);
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.of(context).bg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.of(context).border, width: 0.8),
            ),
            child: Text(
              '${volPercent.toString().padLeft(3)}%',
              style: AppTypography.codeSnippet.copyWith(
                color: vol > 0.8 ? AppColors.of(context).evaPurple : AppColors.of(context).acidGreen,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportDeck(bool isPlaying) {
    return Row(
      children: [
        Expanded(
          child: TactileButton(
            icon: Icons.skip_previous,
            height: 48,
            padding: EdgeInsets.zero,
            onPressed: _playerState.previous,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: TactileButton(
            icon: Icons.stop,
            height: 48,
            padding: EdgeInsets.zero,
            onPressed: _playerState.stop,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          flex: 2,
          child: TactileButton(
            icon: isPlaying ? Icons.pause : Icons.play_arrow,
            height: 52,
            isActive: isPlaying,
            ledColor: AppColors.of(context).acidGreen,
            padding: EdgeInsets.zero,
            onPressed: _playerState.togglePlayPause,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: TactileButton(
            icon: Icons.skip_next,
            height: 48,
            padding: EdgeInsets.zero,
            onPressed: _playerState.next,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: TactileButton(
            icon: Icons.queue_music,
            height: 48,
            padding: EdgeInsets.zero,
            onPressed: _handleOpenQueue,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: TactileButton(
            icon: Icons.tune,
            height: 48,
            padding: EdgeInsets.zero,
            onPressed: _handleOpenPeq,
          ),
        ),
      ],
    );
  }
}

class _MiniPeqCurvePainter extends CustomPainter {
  final PeqState peqState;
  final dynamic colors;

  _MiniPeqCurvePainter({required this.peqState, required this.colors}) : super(repaint: peqState);

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final gridPaint = Paint()
      ..color = colors.border.withOpacity(0.5)
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
      ..color = peqState.isEnabled ? colors.acidGreen : colors.textMuted
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, curvePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniPeqCurvePainter oldDelegate) =>
      oldDelegate.peqState != peqState || oldDelegate.colors != colors;
}
