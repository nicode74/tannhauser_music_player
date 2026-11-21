import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/album_artwork.dart';

/// Tactile Rotary Jog-Wheel Disc Scrubber (Phase 3 Spec)
/// CustomPainter + GestureDetector calculating smooth angular delta (atan2)
/// with wrap-around protection and live preview before committing av_seek_frame.
class DiscSeekWheel extends StatefulWidget {
  final double size;
  final int positionMs;
  final int durationMs;
  final bool isPlaying;
  final bool isUsbConnected;
  final String? artworkPath;
  final ValueChanged<int>? onSeekPreview;
  final ValueChanged<int>? onSeekCommit;

  const DiscSeekWheel({
    super.key,
    this.size = 220.0,
    required this.positionMs,
    required this.durationMs,
    this.isPlaying = false,
    this.isUsbConnected = false,
    this.artworkPath,
    this.onSeekPreview,
    this.onSeekCommit,
  });

  @override
  State<DiscSeekWheel> createState() => _DiscSeekWheelState();
}

class _DiscSeekWheelState extends State<DiscSeekWheel> {
  bool _isDragging = false;
  double? _lastRawAngle;
  double _currentFraction = 0.0;
  int _previewPositionMs = 0;

  double get _fraction {
    if (_isDragging) {
      return _currentFraction;
    }
    if (widget.durationMs <= 0) return 0.0;
    return (widget.positionMs / widget.durationMs).clamp(0.0, 1.0);
  }

  void _onPanStart(DragStartDetails details) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final touch = details.localPosition;
    _lastRawAngle = math.atan2(touch.dy - center.dy, touch.dx - center.dx);
    _currentFraction = widget.durationMs > 0
        ? (widget.positionMs / widget.durationMs).clamp(0.0, 1.0)
        : 0.0;
    _previewPositionMs = widget.positionMs;
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_lastRawAngle == null) return;
    final center = Offset(widget.size / 2, widget.size / 2);
    final touch = details.localPosition;
    final currentRawAngle = math.atan2(touch.dy - center.dy, touch.dx - center.dx);

    double delta = currentRawAngle - _lastRawAngle!;
    _lastRawAngle = currentRawAngle;

    // Handle atan2 wrap-around across [-pi, pi] seamlessly
    if (delta > math.pi) {
      delta -= 2 * math.pi;
    } else if (delta < -math.pi) {
      delta += 2 * math.pi;
    }

    final deltaFraction = delta / (2 * math.pi);
    _currentFraction = (_currentFraction + deltaFraction).clamp(0.0, 1.0);
    _previewPositionMs = (_currentFraction * widget.durationMs).toInt();

    setState(() {});
    widget.onSeekPreview?.call(_previewPositionMs);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    setState(() {
      _isDragging = false;
      _lastRawAngle = null;
    });
    widget.onSeekCommit?.call(_previewPositionMs);
  }

  void _onPanCancel() {
    if (!_isDragging) return;
    setState(() {
      _isDragging = false;
      _lastRawAngle = null;
    });
    widget.onSeekCommit?.call(_previewPositionMs);
  }

  @override
  Widget build(BuildContext context) {
    final displayMs = _isDragging ? _previewPositionMs : widget.positionMs;
    final fraction = _fraction;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Custom Painted Dial & Arc
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _DiscSeekPainter(
                    fraction: fraction,
                    isPlaying: widget.isPlaying,
                    isDragging: _isDragging,
                    isUsbConnected: widget.isUsbConnected,
                  ),
                ),

                // Center Album Artwork Spindle
                AlbumArtwork(
                  imagePath: widget.artworkPath,
                  size: widget.size * 0.44,
                  isCircle: true,
                ),

                // Tiny spindle pin hole
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.bg,
                    border: Border.all(color: AppColors.borderStrong, width: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Monospace Scrub Timestamp Telemetry
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isDragging)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.evaPurpleDim.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.evaPurple, width: 0.8),
                ),
                child: Text(
                  'SCRUB',
                  style: AppTypography.telemetrySmall.copyWith(
                    color: AppColors.evaPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              _formatTime(displayMs),
              style: AppTypography.telemetryMedium.copyWith(
                color: _isDragging ? AppColors.evaPurple : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' / ${_formatTime(widget.durationMs)}',
              style: AppTypography.telemetryMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _DiscSeekPainter extends CustomPainter {
  final double fraction;
  final bool isPlaying;
  final bool isDragging;
  final bool isUsbConnected;

  _DiscSeekPainter({
    required this.fraction,
    required this.isPlaying,
    required this.isDragging,
    required this.isUsbConnected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    // 1. Base Disc Matte Fill & Border
    final basePaint = Paint()
      ..color = AppColors.surfaceInset
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius - 2, basePaint);

    final borderPaint = Paint()
      ..color = isDragging ? AppColors.evaPurple : AppColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, outerRadius - 2, borderPaint);

    // 2. Radial Tick Marks (60 ticks around rim)
    final tickPaint = Paint()
      ..color = AppColors.textMuted.withOpacity(0.4)
      ..strokeWidth = 1.0;
    final majorTickPaint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 1.5;

    final tickRadius = outerRadius - 6;
    for (int i = 0; i < 60; i++) {
      final angle = (i * 2 * math.pi / 60) - (math.pi / 2);
      final isMajor = i % 5 == 0;
      final tickLength = isMajor ? 6.0 : 3.0;

      final start = Offset(
        center.dx + (tickRadius - tickLength) * math.cos(angle),
        center.dy + (tickRadius - tickLength) * math.sin(angle),
      );
      final end = Offset(
        center.dx + tickRadius * math.cos(angle),
        center.dy + tickRadius * math.sin(angle),
      );

      canvas.drawLine(start, end, isMajor ? majorTickPaint : tickPaint);
    }

    // 3. Concentric Machined Vinyl Micro-Grooves
    final groovePaint = Paint()
      ..color = AppColors.border.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(center, outerRadius * 0.85, groovePaint);
    canvas.drawCircle(center, outerRadius * 0.72, groovePaint);
    canvas.drawCircle(center, outerRadius * 0.58, groovePaint);

    // 4. Inactive Arc Track
    final trackRadius = outerRadius - 16;
    final trackPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, trackRadius, trackPaint);

    // 5. Active Sweeping Progress Arc (evaPurple -> acidGreen)
    final sweepAngle = (fraction * 2 * math.pi).clamp(0.0, 2 * math.pi);
    if (sweepAngle > 0.001) {
      final arcRect = Rect.fromCircle(center: center, radius: trackRadius);
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.5;

      if (isDragging) {
        arcPaint.color = AppColors.evaPurple;
      } else {
        arcPaint.shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [
            AppColors.evaPurple,
            AppColors.acidGreen,
          ],
        ).createShader(arcRect);
      }

      canvas.drawArc(arcRect, -math.pi / 2, sweepAngle, false, arcPaint);

      // 6. Glowing Scrubber Head Dot at Arc Tip
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipCenter = Offset(
        center.dx + trackRadius * math.cos(tipAngle),
        center.dy + trackRadius * math.sin(tipAngle),
      );

      final dotColor = isDragging
          ? AppColors.evaPurple
          : (isPlaying ? AppColors.acidGreen : AppColors.evaPurple);

      // Outer Glow
      final glowPaint = Paint()
        ..color = dotColor.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tipCenter, 7.0, glowPaint);

      // Inner Core Dot
      final corePaint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tipCenter, 4.0, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiscSeekPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.isUsbConnected != isUsbConnected;
  }
}
