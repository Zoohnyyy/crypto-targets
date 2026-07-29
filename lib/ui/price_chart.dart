import 'package:flutter/material.dart';

import '../services/market_history_service.dart';

const _green = Color(0xFF16C784);
const _red = Color(0xFFEA3943);

/// A lightweight line chart for a coin's price series, drawn with CustomPaint
/// (no charting dependency). Colored green/red by net change over the range,
/// with a soft gradient fill and theme-aware axis labels.
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.points});

  final List<PricePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const Center(child: Text('No chart data'));
    }

    final up = points.last.price >= points.first.price;
    final lineColor = up ? _green : _red;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return CustomPaint(
      painter: _ChartPainter(
        points: points,
        lineColor: lineColor,
        labelColor: labelColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.lineColor,
    required this.labelColor,
  });

  final List<PricePoint> points;
  final Color lineColor;
  final Color labelColor;

  // Left gutter for price labels, bottom gutter left as breathing room.
  static const double _leftPad = 8;
  static const double _rightPad = 56;
  static const double _topPad = 12;
  static const double _bottomPad = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _leftPad - _rightPad;
    final chartH = size.height - _topPad - _bottomPad;

    double minP = points.first.price;
    double maxP = points.first.price;
    for (final p in points) {
      if (p.price < minP) minP = p.price;
      if (p.price > maxP) maxP = p.price;
    }
    final range = (maxP - minP).abs() < 1e-9 ? 1.0 : (maxP - minP);

    Offset toOffset(int i) {
      final x = _leftPad + chartW * (i / (points.length - 1));
      final y = _topPad + chartH * (1 - (points[i].price - minP) / range);
      return Offset(x, y);
    }

    // Horizontal grid lines + right-edge price labels (min, mid, max).
    final gridPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    for (var g = 0; g <= 2; g++) {
      final frac = g / 2;
      final y = _topPad + chartH * frac;
      canvas.drawLine(Offset(_leftPad, y), Offset(_leftPad + chartW, y),
          gridPaint);
      final value = maxP - range * frac;
      _drawText(
        canvas,
        _fmtPrice(value),
        Offset(_leftPad + chartW + 4, y - 6),
        labelColor,
      );
    }

    // The line path.
    final linePath = Path()..moveTo(toOffset(0).dx, toOffset(0).dy);
    for (var i = 1; i < points.length; i++) {
      final o = toOffset(i);
      linePath.lineTo(o.dx, o.dy);
    }

    // Gradient fill under the line.
    final fillPath = Path.from(linePath)
      ..lineTo(toOffset(points.length - 1).dx, _topPad + chartH)
      ..lineTo(toOffset(0).dx, _topPad + chartH)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha: 0.28), lineColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(_leftPad, _topPad, chartW, chartH));
    canvas.drawPath(fillPath, fillPaint);

    // The line itself.
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawText(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  String _fmtPrice(double v) {
    if (v >= 1000) return '\$${v.toStringAsFixed(0)}';
    if (v >= 1) return '\$${v.toStringAsFixed(2)}';
    return '\$${v.toStringAsFixed(4)}';
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points ||
      old.lineColor != lineColor ||
      old.labelColor != labelColor;
}
