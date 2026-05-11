import 'package:flutter/material.dart';
import '../models/bead.dart';
import '../models/pattern_step.dart';
import 'bead_widget.dart';

class BeadBoard extends StatelessWidget {
  final List<PatternStep> steps;
  final int currentStepIndex;
  final double beadSize;

  const BeadBoard({
    super.key,
    required this.steps,
    required this.currentStepIndex,
    this.beadSize = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty || currentStepIndex < 0) {
      return const SizedBox.shrink();
    }

    final placements = _computePlacements();
    if (placements.isEmpty) return const SizedBox.shrink();

    double maxX = 0, maxY = 0;
    for (final p in placements) {
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }

    final double totalWidth = maxX * beadSize + beadSize;
    final double totalHeight = maxY * beadSize + beadSize;

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final p in placements)
            Positioned(
              left: p.x * beadSize,
              top: p.y * beadSize,
              child: BeadWidget(bead: p.bead, size: beadSize),
            ),
        ],
      ),
    );
  }

  // Peyote rendering model (matches user's reference app):
  //
  // Etapa 1 (currentStepIndex == 0):
  //   Foundation rendered as a single vertical column.
  //   data[N-1] at top (Y=0), data[0] at bottom (Y=N-1).
  //
  // Etapa 2+ (currentStepIndex >= 1): "se devuelve" reshapes the foundation:
  //   Row 0 (top): a PAIR of beads at X=0 and X=1
  //     - data[N-1] at (X=0, Y=0)
  //     - data[N-2] at (X=1, Y=0)
  //   Below the top pair, the remaining N-2 beads alternate SINGLE / PARTIAL_PAIR rows:
  //     - Row 1, 3, 5, … (odd): SINGLE bead at X=0.5 (centered)
  //     - Row 2, 4, 6, … (even): PARTIAL PAIR — foundation bead at X=0 (LEFT)
  //   Going top→down: data[N-3], data[N-4], data[N-5], … data[0]
  //   data[0] sits at the bottom-most single row (centered).
  //
  // Step 1's beads (etapa 2) fill the partial-pair rows on the RIGHT (X=1):
  //   Step 1 weaves TOP-DOWN (user's convention): data[0] is the topmost added.
  //   data[0] at the top partial-pair row (Y=2)
  //   data[1] at the next partial-pair row (Y=4)
  //   data[2] at Y=6, data[3] at Y=8, …
  //
  // (Step S >= 2 handling: TBD, left as a new column for now until user confirms.)
  List<_Placement> _computePlacements() {
    final placements = <_Placement>[];
    if (steps.isEmpty) return placements;

    final foundation = steps[0].beads;
    final int n0 = foundation.length;

    // --- Etapa 1: single vertical column ---
    if (currentStepIndex == 0) {
      for (int i = 0; i < n0; i++) {
        placements.add(_Placement(0.0, (n0 - 1 - i).toDouble(), foundation[i]));
      }
      return placements;
    }

    // --- Etapa 2+: zigzag with top pair, alternating single/partial-pair rows ---
    if (n0 >= 1) {
      // Top pair LEFT (Y=0, X=0)
      placements.add(_Placement(0.0, 0.0, foundation[n0 - 1]));
    }
    if (n0 >= 2) {
      // Top pair RIGHT (Y=0, X=1)
      placements.add(_Placement(1.0, 0.0, foundation[n0 - 2]));
    }

    // Foundation single beads ALWAYS stay at X=0.5 (centered).
    // Step 3 beads, when present, sit at X=1.5 (right of singles, half-offset).
    const double singleX = 0.5;

    // Remaining N-2 foundation beads: alternate SINGLE and PARTIAL_PAIR rows.
    // First remaining bead goes to Y=1 (SINGLE row).
    int row = 1;
    for (int j = 0; j < n0 - 2; j++) {
      final Bead bead = foundation[n0 - 3 - j];
      if (row % 2 == 1) {
        // odd row -> single, centered at X=0.5
        placements.add(_Placement(singleX, row.toDouble(), bead));
      } else {
        // even row (>=2) -> partial pair, foundation on LEFT
        placements.add(_Placement(0.0, row.toDouble(), bead));
      }
      row++;
    }

    // --- Step 1 (etapa 2): fill partial-pair rows on the RIGHT (X=1) ---
    if (currentStepIndex >= 1 && steps.length > 1) {
      final step1 = steps[1].beads;
      // Partial-pair rows start at Y=2 and step by 2 (Y=2, 4, 6, …)
      for (int k = 0; k < step1.length; k++) {
        final int targetRow = 2 + k * 2;
        placements.add(_Placement(1.0, targetRow.toDouble(), step1[k]));
      }
    }

    // --- Steps 3 and onwards: fill remaining columns following the alternating pattern ---
    for (int s = 2; s <= currentStepIndex && s < steps.length; s++) {
      final beads = steps[s].beads;
      final int n = beads.length;
      if (n == 0) continue;

      // Logic:
      // Step 3 (s=2): Odd step -> fill half-number X (1.5) and Y (1, 3, 5...)
      // Step 4 (s=3): Even step -> fill whole-number X (2.0) and Y (0, 2, 4...)
      final bool isEvenStep = (s % 2 == 1); 
      final double colX = 1.0 + (s - 1) * 0.5;
      
      // Determine Y positions for this column
      final List<int> targetYs = [];
      if (!isEvenStep) {
        // Odd steps (s=2, 4...) -> Y = 1, 3, 5...
        for (int y = 1; y < n0; y += 2) {
          targetYs.add(y);
        }
      } else {
        // Even steps (s=3, 5...) -> Y = 0, 2, 4...
        for (int y = 0; y < n0; y += 2) {
          targetYs.add(y);
        }
      }

      // Weave direction (up/down) alternating
      final bool weavingDown = (s % 2 == 1);
      for (int i = 0; i < n; i++) {
        int targetIdx = weavingDown ? i : (targetYs.length - 1 - i);
        if (targetIdx >= 0 && targetIdx < targetYs.length) {
          final int targetY = targetYs[targetIdx];
          
          // IMPORTANT: Skip Y=0 ONLY for the foundation area (X=0 and X=1)
          // Steps 4, 6... (s=3, 5...) at X=2.0, 3.0... CAN have beads at Y=0.
          if (targetY == 0 && colX < 1.1) continue; 
          
          placements.add(_Placement(colX, targetY.toDouble(), beads[i]));
        }
      }
    }

    return placements;
  }
}

class _Placement {
  final double x;
  final double y;
  final Bead bead;
  _Placement(this.x, this.y, this.bead);
}
