import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// EVA-01 Tactical Audio Terminal Animated Splash Screen
/// Inspired by NERV UI, MAGI boot sequence, and EVA-01 Sync Rate HUD.
class EvaSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const EvaSplashScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<EvaSplashScreen> createState() => _EvaSplashScreenState();
}

class _EvaSplashScreenState extends State<EvaSplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progressAnimation;
  bool _isCompleted = false;

  final List<String> _bootLogs = [
    '> BOOT: TANNHÄUSER AUDIO CORE // UNIT-01',
    '> BYPASS: ANDROID AUDIOFLINGER MIXER [OVERRIDE ACTIVE]',
    '> NATIVE NDK: LIBUSB UAC2 ISOCHRONOUS STREAM [ARMED]',
    '> 64-BIT PEQ DSP: RBJ TDF-II CASCADED BIQUAD [READY]',
    '> SYNCHRO RATE: 100.0% // ALL SYSTEMS NOMINAL',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _progressAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.addListener(() {
      setState(() {});
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            _finishSplash();
          }
        });
      }
    });

    _controller.forward();
  }

  void _finishSplash() {
    if (_isCompleted) return;
    _isCompleted = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progressAnimation.value;
    final syncRate = (progress * 100.0).clamp(0.0, 100.0);
    final activeLogsCount = (progress * (_bootLogs.length + 1)).floor().clamp(1, _bootLogs.length);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finishSplash,
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Hazard Warning Bar
              const _HazardStripeBar(height: 6),
              const SizedBox(height: AppSpacing.sm),

              // 2. Top Status Telemetry Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '[ NERV // AUDIO TELEMETRY ]',
                      style: AppTypography.telemetrySmall.copyWith(
                        color: AppColors.hazardOrange,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'UNIT-01 : BIT-PERFECT',
                      style: AppTypography.telemetrySmall.copyWith(
                        color: AppColors.evaPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // 3. Central EVA-01 Title Emblem & Synchro Oscilloscope
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppSpacing.borderPanel,
                    border: Border.all(
                      color: progress >= 0.95 ? AppColors.acidGreen : AppColors.borderStrong,
                      width: 1.5,
                    ),
                    boxShadow: progress >= 0.95
                        ? [
                            BoxShadow(
                              color: AppColors.acidGreen.withOpacity(0.15),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      // Subtitle tag
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.hazardOrange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'EMERGENCY AUDIO CONSOLE',
                            style: AppTypography.telemetrySmall.copyWith(
                              letterSpacing: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Main Title
                      Text(
                        'TANNHÄUSER',
                        style: AppTypography.header.copyWith(
                          fontSize: 28,
                          letterSpacing: 4.0,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Text(
                        '// UNIT-01 BIT-PERFECT TERMINAL //',
                        style: AppTypography.telemetrySmall.copyWith(
                          color: AppColors.evaPurple,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 4. Oscilloscope Synchro Waveform Canvas
                      Container(
                        height: 64,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceInset,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: CustomPaint(
                          painter: _SynchroWaveformPainter(
                            progress: progress,
                            accentColor: progress >= 0.85 ? AppColors.acidGreen : AppColors.evaPurple,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Synchro Rate Digital Readout
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SYNCHRO RATE',
                            style: AppTypography.telemetrySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${syncRate.toStringAsFixed(1)} %',
                            style: AppTypography.telemetryLarge.copyWith(
                              color: progress >= 0.85 ? AppColors.acidGreen : AppColors.evaPurple,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 5. Terminal Boot Telemetry Stream
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  height: 110,
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceInset,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeLogsCount,
                    itemBuilder: (context, idx) {
                      final log = _bootLogs[idx];
                      final isLatest = idx == activeLogsCount - 1;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Text(
                          log,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.telemetrySmall.copyWith(
                            fontSize: 9.5,
                            color: isLatest
                                ? (progress >= 0.95 ? AppColors.acidGreen : AppColors.textPrimary)
                                : AppColors.textMuted,
                            fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 6. Segmented LED Loading Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _buildSegmentedLedBar(progress),
              ),

              const Spacer(flex: 2),

              // 7. Tap to Skip Instruction Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceInset,
                  borderRadius: AppSpacing.borderBadge,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '[ KETUK LAYAR UNTUK MELOMPATI ]',
                  style: AppTypography.telemetrySmall.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // 8. Bottom Hazard Warning Bar
              const _HazardStripeBar(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedLedBar(double progress) {
    const totalSegments = 24;
    final activeSegments = (progress * totalSegments).floor();

    return Row(
      children: List.generate(totalSegments, (idx) {
        final isActive = idx < activeSegments;
        final color = progress >= 0.85 ? AppColors.acidGreen : AppColors.evaPurple;

        return Expanded(
          child: Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 1.0),
            decoration: BoxDecoration(
              color: isActive ? color : AppColors.surfaceInset,
              borderRadius: BorderRadius.circular(1.5),
              border: Border.all(
                color: isActive ? color : AppColors.border,
                width: 0.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 3,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

/// NERV Hazard Diagonal Warning Stripe Bar
class _HazardStripeBar extends StatelessWidget {
  final double height;

  const _HazardStripeBar({this.height = 6.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _HazardStripePainter(),
      ),
    );
  }
}

class _HazardStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = AppColors.hazardOrange
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = AppColors.surfaceInset
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, bgPaint);

    const stripeWidth = 8.0;
    const gap = 8.0;
    final totalWidth = size.width + size.height;

    for (double x = -size.height; x < totalWidth; x += (stripeWidth + gap)) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripeWidth, size.height)
        ..lineTo(x + stripeWidth + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Oscilloscope Synchro Waveform Visualizer
class _SynchroWaveformPainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  _SynchroWaveformPainter({
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final w = size.width;
    final h = size.height;

    // 1. Grid Lines
    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.4)
      ..strokeWidth = 0.8;

    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);
    for (double x = 0; x < w; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // 2. Harmonic Sine Waveform
    final wavePath = Path();
    final wavePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final amplitude = (h * 0.35) * math.sin(progress * math.pi * 0.5);
    final frequency = 2.0 + (progress * 4.0);
    final phase = progress * math.pi * 6.0;

    for (double x = 0; x <= w; x += 2.0) {
      final normalizedX = x / w;
      // Envelope window (smooth taper at edges)
      final envelope = math.sin(normalizedX * math.pi);
      final y = midY - math.sin((normalizedX * frequency * 2 * math.pi) - phase) * amplitude * envelope;

      if (x == 0) {
        wavePath.moveTo(x, y);
      } else {
        wavePath.lineTo(x, y);
      }
    }

    // Outer glow
    final glowPaint = Paint()
      ..color = accentColor.withOpacity(0.3)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(wavePath, glowPaint);
    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _SynchroWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.accentColor != accentColor;
  }
}
