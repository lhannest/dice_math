import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class DieMark extends StatelessWidget {
  const DieMark({this.size = 112, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(size: Size.square(size), painter: _DiePainter()),
  );
}

class _DiePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .44;
    final vertices = List.generate(
      6,
      (i) =>
          center +
          Offset(
            cos(-pi / 2 + i * pi / 3) * radius,
            sin(-pi / 2 + i * pi / 3) * radius,
          ),
    );
    final path = Path()..addPolygon(vertices, true);
    canvas.drawPath(path, Paint()..color = gold.withValues(alpha: .04));
    final paint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, paint);
    final a = vertices[0];
    final b = vertices[2];
    final c = vertices[4];
    canvas.drawPath(Path()..addPolygon([a, b, c], true), paint);
    canvas.drawLine(vertices[1], b, paint);
    canvas.drawLine(vertices[3], b, paint);
    canvas.drawLine(vertices[3], c, paint);
    canvas.drawLine(vertices[5], c, paint);
    canvas.drawLine(vertices[1], a, paint);
    canvas.drawLine(vertices[5], a, paint);
    final text = TextPainter(
      text: const TextSpan(
        text: '±',
        style: TextStyle(
          color: gold,
          fontFamily: 'sans-serif',
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2 - 3));
  }

  @override
  bool shouldRepaint(_DiePainter oldDelegate) => false;
}
