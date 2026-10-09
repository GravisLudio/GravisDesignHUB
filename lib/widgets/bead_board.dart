import 'dart:math';
import 'package:flutter/material.dart';
import '../models/bead.dart';
import '../models/pattern_step.dart';
import 'bead_widget.dart';

class BeadBoard extends StatelessWidget {
  final List<PatternStep> steps;
  final int currentStepIndex;
  final double beadSize;
  final String patternType; // 'peyote', 'loom', 'brick', 'flower'
  final bool showThreadGuide;

  const BeadBoard({
    super.key,
    required this.steps,
    required this.currentStepIndex,
    this.beadSize = 40.0,
    this.patternType = 'peyote',
    this.showThreadGuide = false,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty || currentStepIndex < 0) {
      return const SizedBox.shrink();
    }

    final placements = _computePlacements();
    if (placements.isEmpty) return const SizedBox.shrink();

    double maxX = -double.infinity, maxY = -double.infinity;
    double minX = double.infinity, minY = double.infinity;
    for (final p in placements) {
      if (p.x > maxX) maxX = p.x;
      if (p.x < minX) minX = p.x;
      if (p.y > maxY) maxY = p.y;
      if (p.y < minY) minY = p.y;
    }

    if (maxX == -double.infinity) {
      maxX = 0; minX = 0; maxY = 0; minY = 0;
    }

    final double totalWidth = (maxX - minX) * beadSize + beadSize;
    final double totalHeight = (maxY - minY) * beadSize + beadSize;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Render all placed beads
          for (final p in placements)
            Positioned(
              left: (p.x - minX) * beadSize,
              top: (p.y - minY) * beadSize,
              child: Transform.rotate(
                angle: p.angle,
                child: BeadWidget(bead: p.bead, size: beadSize),
              ),
            ),
          // 2. Render thread guide on top if requested
          if (showThreadGuide)
            Positioned.fill(
              child: CustomPaint(
                painter: ThreadGuidePainter(
                  placements: placements,
                  currentStepIndex: currentStepIndex,
                  patternType: patternType,
                  beadSize: beadSize,
                  minX: minX,
                  minY: minY,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_Placement> _computePlacements() {
    final placements = <_Placement>[];
    if (steps.isEmpty) return placements;

    // --- Type: peyote (Miyuki classic vertical staggered) ---
    if (patternType == 'peyote') {
      final foundation = steps[0].beads;
      final int n0 = foundation.length;

      // Etapa 1: single vertical column
      if (currentStepIndex == 0) {
        for (int i = 0; i < n0; i++) {
          placements.add(_Placement(0.0, (n0 - 1 - i).toDouble(), foundation[i], 0, i, angle: pi / 2));
        }
        return placements;
      }

      // Etapa 2+: zigzag with top pair, alternating single/partial-pair rows
      if (n0 >= 2) {
        placements.add(_Placement(0.0, 0.0, foundation[n0 - 2], 0, n0 - 2, angle: pi / 2));
        placements.add(_Placement(1.0, 0.0, foundation[n0 - 1], 0, n0 - 1, angle: pi / 2));
      } else if (n0 == 1) {
        placements.add(_Placement(0.0, 0.0, foundation[0], 0, 0, angle: pi / 2));
      }

      const double singleX = 0.5;
      int row = 1;
      for (int j = 0; j < n0 - 2; j++) {
        final Bead bead = foundation[n0 - 3 - j];
        if (row % 2 == 1) {
          placements.add(_Placement(singleX, row.toDouble(), bead, 0, n0 - 3 - j, angle: pi / 2));
        } else {
          placements.add(_Placement(0.0, row.toDouble(), bead, 0, n0 - 3 - j, angle: pi / 2));
        }
        row++;
      }

      // Step 1 (etapa 2)
      if (currentStepIndex >= 1 && steps.length > 1) {
        final step1 = steps[1].beads;
        for (int k = 0; k < step1.length; k++) {
          final int targetRow = 2 + k * 2;
          placements.add(_Placement(1.0, targetRow.toDouble(), step1[k], 1, k, angle: pi / 2));
        }
      }

      // Steps 2 and onwards
      int rightColIndex = 2;
      int leftColIndex = 2;

      for (int s = 2; s <= currentStepIndex && s < steps.length; s++) {
        final step = steps[s];
        final beads = step.beads;
        final int n = beads.length;
        if (n == 0) continue;

        bool isLeft = step.note == 'LEFT_SIDE';
        int validColIndex = isLeft ? leftColIndex : rightColIndex;
        final bool isEvenStep = (validColIndex % 2 == 1);
        final double colX = isLeft 
            ? 0.0 - (validColIndex - 1) * 0.5
            : 1.0 + (validColIndex - 1) * 0.5;

        final List<int> targetYs = [];
        if (!isEvenStep) {
          for (int y = 1; y < n0; y += 2) {
            targetYs.add(y);
          }
        } else {
          for (int y = 0; y < n0; y += 2) {
            targetYs.add(y);
          }
        }

        final bool weavingDown = (validColIndex % 2 == 1);
        for (int i = 0; i < n; i++) {
          int targetIdx = weavingDown ? i : (targetYs.length - 1 - i);
          if (targetIdx >= 0 && targetIdx < targetYs.length) {
            final int targetY = targetYs[targetIdx];
            if (targetY == 0 && colX > -0.1 && colX < 1.1) continue;
            placements.add(_Placement(colX, targetY.toDouble(), beads[i], s, i, angle: pi / 2));
          }
        }

        if (isLeft) {
          leftColIndex++;
        } else {
          rightColIndex++;
        }
      }
      return placements;
    }

    return placements;
  }
}

class _Placement {
  final double x;
  final double y;
  final Bead bead;
  final int stepIndex;
  final int beadIndex;
  final double angle;

  _Placement(this.x, this.y, this.bead, this.stepIndex, this.beadIndex, {this.angle = 0.0});
}

class ThreadGuidePainter extends CustomPainter {
  final List<_Placement> placements;
  final int currentStepIndex;
  final String patternType;
  final double beadSize;
  final double minX;
  final double minY;

  ThreadGuidePainter({
    required this.placements,
    required this.currentStepIndex,
    required this.patternType,
    required this.beadSize,
    required this.minX,
    required this.minY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final currentPlacements = placements
        .where((p) => p.stepIndex == currentStepIndex)
        .toList()
      ..sort((a, b) => a.beadIndex.compareTo(b.beadIndex));

    if (currentPlacements.isEmpty) return;

    final paintThread = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset getBeadOffset(_Placement p) {
      return Offset(
        (p.x - minX) * beadSize + beadSize / 2,
        (p.y - minY) * beadSize + beadSize / 2,
      );
    }

    // Peyote
    for (int i = 0; i < currentPlacements.length; i++) {
      final p = currentPlacements[i];
      final center = getBeadOffset(p);

      if (i == 0) {
        canvas.drawLine(center - Offset(0, beadSize * 0.5), center, paintThread);
      } else {
        final prevCenter = getBeadOffset(currentPlacements[i - 1]);
        canvas.drawLine(prevCenter, center, paintThread);
      }

      if (i == currentPlacements.length - 1) {
        _drawNeedle(canvas, center + Offset(0, beadSize * 0.4), const Offset(0, 1));
      }
    }
  }

  void _drawNeedle(Canvas canvas, Offset position, Offset dir) {
    final angle = atan2(dir.dy, dir.dx);
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);

    final needlePaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final eyePaint = Paint()
      ..color = Colors.amber.shade700
      ..style = PaintingStyle.fill;

    canvas.drawLine(const Offset(-25, 0), const Offset(0, 0), needlePaint);
    final pathPoint = Path()
      ..moveTo(0, 0)
      ..lineTo(-5, -2)
      ..lineTo(-5, 2)
      ..close();
    canvas.drawPath(pathPoint, Paint()..color = Colors.grey.shade600..style = PaintingStyle.fill);

    canvas.drawCircle(const Offset(-22, 0), 1.5, eyePaint);

    final threadTailPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final tailPath = Path()
      ..moveTo(-22, 0)
      ..cubicTo(-28, -5, -30, 5, -36, 0);
    canvas.drawPath(tailPath, threadTailPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ThreadGuidePainter oldDelegate) =>
      oldDelegate.currentStepIndex != currentStepIndex ||
      oldDelegate.patternType != patternType ||
      oldDelegate.beadSize != beadSize ||
      oldDelegate.minX != minX ||
      oldDelegate.minY != minY ||
      oldDelegate.placements.length != placements.length;
}
