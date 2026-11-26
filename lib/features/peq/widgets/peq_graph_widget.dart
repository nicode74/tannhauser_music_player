import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../controllers/peq_state.dart';

/// Interactive Parametric EQ Frequency Response Curve Visualizer
class PeqGraphWidget extends StatelessWidget {
  final PeqState peqState;
  final double height;
  final Function(int bandIndex, double newFc, double newGain)? onNodeDragged;

  const PeqGraphWidget({
    super.key,
    required this.peqState,
    this.height = 180.0,
    this.onNodeDragged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceInset,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = details.localPosition;
            final w = box.size.width;
            final h = box.size.height;

            // X to Log Frequency (20 to 20000 Hz)
            final fractionX = (local.dx / w).clamp(0.0, 1.0);
            const minFreq = 20.0;
            const maxFreq = 20000.0;
            final freq = math.exp(math.log(minFreq) + fractionX * (math.log(maxFreq) - math.log(minFreq)));

            // Y to Gain (+15dB to -15dB)
            final fractionY = (local.dy / h).clamp(0.0, 1.0);
            final gain = 15.0 - (fractionY * 30.0);

            peqState.updateSelectedBand(fc: freq, gainDb: gain);
          },
          child: CustomPaint(
            painter: _PeqGraphPainter(peqState: peqState, colors: colors),
          ),
        ),
      ),
    );
  }
}

class _PeqGraphPainter extends CustomPainter {
  final PeqState peqState;
  final dynamic colors;

  _PeqGraphPainter({required this.peqState, required this.colors});

  double _freqToX(double f, double width) {
    const minFreq = 20.0;
    const maxFreq = 20000.0;
    final logMin = math.log(minFreq);
    final logMax = math.log(maxFreq);
    return ((math.log(f) - logMin) / (logMax - logMin)) * width;
  }

  double _gainToY(double gainDb, double height) {
    const maxDb = 15.0;
    const minDb = -15.0;
    return height - ((gainDb - minDb) / (maxDb - minDb)) * height;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Grid Lines (Horizontal dB lines)
    final gridPaint = Paint()
      ..color = colors.border.withOpacity(0.4)
      ..strokeWidth = 0.8;

    final dBLines = [-12.0, -6.0, 0.0, 6.0, 12.0];
    for (final db in dBLines) {
      final y = _gainToY(db, h);
      final isZero = db == 0.0;
      final linePaint = Paint()
        ..color = isZero ? colors.borderStrong : colors.border.withOpacity(0.3)
        ..strokeWidth = isZero ? 1.2 : 0.8;
      canvas.drawLine(Offset(0, y), Offset(w, y), linePaint);
    }

    // 2. Grid Lines (Vertical Frequency lines)
    final freqLines = [50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0];
    for (final f in freqLines) {
      final x = _freqToX(f, w);
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // 3. Response Curve (acidGreen or textMuted if bypassed)
    final curvePoints = peqState.computeResponseCurve();
    final curvePath = Path();

    for (int i = 0; i < curvePoints.length; i++) {
      final pt = curvePoints[i];
      final x = _freqToX(pt.dx, w);
      final y = _gainToY(pt.dy, h);
      if (i == 0) {
        curvePath.moveTo(x, y);
      } else {
        curvePath.lineTo(x, y);
      }
    }

    final curvePaint = Paint()
      ..color = peqState.isEnabled ? colors.acidGreen : colors.textMuted
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(curvePath, curvePaint);

    // 4. Band Control Nodes
    if (peqState.isEnabled) {
      for (int i = 0; i < peqState.bands.length; i++) {
        final b = peqState.bands[i];
        if (!b.enabled) continue;

        final isSelected = i == peqState.selectedBandIndex;
        final x = _freqToX(b.fc, w);
        final y = _gainToY(b.gainDb, h);
        final nodeColor = isSelected ? colors.acidGreen : colors.evaPurple;

        // Node Glow
        if (isSelected) {
          final glowPaint = Paint()
            ..color = colors.acidGreen.withOpacity(0.3)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(x, y), 8.0, glowPaint);
        }

        // Node Core
        final nodePaint = Paint()
          ..color = nodeColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), isSelected ? 4.5 : 3.0, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PeqGraphPainter oldDelegate) => true;
}
