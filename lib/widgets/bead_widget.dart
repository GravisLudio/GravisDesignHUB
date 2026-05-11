import 'package:flutter/material.dart';
import '../models/bead.dart';

class BeadWidget extends StatelessWidget {
  final Bead bead;
  final double size;

  const BeadWidget({
    super.key,
    required this.bead,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    if (bead.isEmpty || bead.beadColor == null) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: EmptyBeadPainter(),
        ),
      );
    }

    final bool isLight = bead.beadColor!.color.computeLuminance() > 0.7;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [
            bead.beadColor!.color.withOpacity(0.9),
            bead.beadColor!.color,
            bead.beadColor!.color.withOpacity(0.8),
            Color.lerp(bead.beadColor!.color, Colors.black, 0.2)!,
          ],
          stops: const [0.0, 0.4, 0.8, 1.0],
        ),
        border: isLight
            ? Border.all(color: Colors.grey.shade300, width: 0.8)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 5,
            offset: const Offset(1.5, 2),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner gloss/highlight
          Positioned(
            top: size * 0.15,
            left: size * 0.15,
            child: Container(
              width: size * 0.35,
              height: size * 0.35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Small reflection dot
          Positioned(
            top: size * 0.1,
            left: size * 0.1,
            child: Container(
              width: size * 0.15,
              height: size * 0.15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
          // Subtle hole in the middle (Peyote style)
          Center(
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyBeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;

    // Draw a 'U' shape (cup) representing the placeholder for a bead
    final path = Path()
      ..moveTo(w * 0.2, h * 0.4)
      ..quadraticBezierTo(w * 0.2, h * 0.8, w * 0.5, h * 0.8)
      ..quadraticBezierTo(w * 0.8, h * 0.8, w * 0.8, h * 0.4);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
