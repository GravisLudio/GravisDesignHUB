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
    if (bead.isEmpty || bead.beadColor == null || bead.beadColor!.color == Colors.transparent) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: EmptyBeadPainter(),
        ),
      );
    }

    return CustomPaint(
      size: Size(size, size),
      painter: CylinderBeadPainter(color: bead.beadColor!.color),
    );
  }
}

class CylinderBeadPainter extends CustomPainter {
  final Color color;

  CylinderBeadPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // The bead is a horizontal cylinder. 
    // We restrict the height slightly to make it cylindrical (capsule shape)
    final double beadHeight = h * 0.76;
    final double topY = (h - beadHeight) / 2;
    final double bottomY = topY + beadHeight;
    final double radius = beadHeight * 0.32; // Rounded cylindrical edges

    final Rect rect = Rect.fromLTRB(0, topY, w, bottomY);
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Drop Shadow for 3D depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
    canvas.drawRRect(rrect.shift(const Offset(1.0, 1.5)), shadowPaint);

    // 2. 3D Volume shading using a Linear Gradient from top to bottom
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _lighten(color, 0.42), // Top reflection highlight
        _lighten(color, 0.20), // Specular glow area
        color,                 // Core color
        _darken(color, 0.22),  // Shadow roll-off
        _darken(color, 0.45),  // Deep bottom shade
      ],
      stops: const [0.0, 0.22, 0.52, 0.82, 1.0],
    );
    
    paint.shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);

    // 3. Precise border outline
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _darken(color, 0.35);
    canvas.drawRRect(rrect, borderPaint);

    // 4. Highlight reflection stripe (specular reflection gloss)
    final highlightPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.35),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, topY + beadHeight * 0.1, w, beadHeight * 0.15));
    
    final highlightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.1, topY + beadHeight * 0.1, w * 0.8, beadHeight * 0.12),
      Radius.circular(radius * 0.5),
    );
    canvas.drawRRect(highlightRect, highlightPaint);

    // 5. Thread hole (inner shadow/tube representation)
    final holePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = beadHeight * 0.14
      ..color = Colors.black.withOpacity(0.22)
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(
      Offset(w * 0.08, h / 2),
      Offset(w * 0.92, h / 2),
      holePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CylinderBeadPainter oldDelegate) => oldDelegate.color != color;

  Color _lighten(Color c, double fraction) {
    return Color.fromARGB(
      c.alpha,
      (c.red + (255 - c.red) * fraction).round().clamp(0, 255),
      (c.green + (255 - c.green) * fraction).round().clamp(0, 255),
      (c.blue + (255 - c.blue) * fraction).round().clamp(0, 255),
    );
  }

  Color _darken(Color c, double fraction) {
    return Color.fromARGB(
      c.alpha,
      (c.red * (1.0 - fraction)).round().clamp(0, 255),
      (c.green * (1.0 - fraction)).round().clamp(0, 255),
      (c.blue * (1.0 - fraction)).round().clamp(0, 255),
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

    final path = Path()
      ..moveTo(w * 0.2, h * 0.4)
      ..quadraticBezierTo(w * 0.2, h * 0.8, w * 0.5, h * 0.8)
      ..quadraticBezierTo(w * 0.8, h * 0.8, w * 0.8, h * 0.4);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
