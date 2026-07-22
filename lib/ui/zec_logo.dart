import 'package:flutter/material.dart';

/// The Zcash (ZEC) logo, drawn as a vector so the "Z" can be recolored by
/// theme: white in dark mode, black in light mode, on the Zcash gold disc.
///
/// CoinGecko only serves a single fixed PNG (gold disc, black Z), which looks
/// wrong on dark backgrounds — hence this bundled, theme-aware version.
class ZecLogo extends StatelessWidget {
  const ZecLogo({super.key, required this.size, required this.brightness});

  final double size;
  final Brightness brightness;

  /// Official Zcash gold.
  static const Color _gold = Color(0xFFF4B728);

  @override
  Widget build(BuildContext context) {
    final zColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;
    return CustomPaint(
      size: Size.square(size),
      painter: _ZecPainter(discColor: _gold, zColor: zColor),
    );
  }
}

class _ZecPainter extends CustomPainter {
  _ZecPainter({required this.discColor, required this.zColor});

  final Color discColor;
  final Color zColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w / 2;
    final center = Offset(r, r);

    // Gold disc.
    canvas.drawCircle(center, r, Paint()..color = discColor);

    // Draw a "Z" (top bar, diagonal, bottom bar) plus the vertical serifs that
    // the Zcash mark has above and below the Z.
    final z = Path();
    // Coordinates as fractions of the disc for crisp scaling.
    double x(double f) => f * w;
    double y(double f) => f * w;

    final barH = 0.11; // bar thickness (fraction)

    // Top horizontal bar.
    z.addRect(Rect.fromLTRB(x(0.28), y(0.26), x(0.72), y(0.26 + barH)));
    // Bottom horizontal bar.
    z.addRect(Rect.fromLTRB(x(0.28), y(0.63), x(0.72), y(0.63 + barH)));
    // Diagonal stroke from top-right to bottom-left.
    final diag = Path()
      ..moveTo(x(0.72), y(0.26))
      ..lineTo(x(0.72), y(0.37))
      ..lineTo(x(0.40), y(0.63))
      ..lineTo(x(0.28), y(0.63))
      ..lineTo(x(0.28), y(0.52))
      ..lineTo(x(0.60), y(0.26 + barH))
      ..lineTo(x(0.72), y(0.26 + barH))
      ..close();
    z.addPath(diag, Offset.zero);

    // Short vertical serifs above and below (the Zcash "I"-like accents).
    z.addRect(Rect.fromLTRB(x(0.455), y(0.15), x(0.545), y(0.26)));
    z.addRect(Rect.fromLTRB(x(0.455), y(0.74), x(0.545), y(0.85)));

    canvas.drawPath(z, Paint()..color = zColor);
  }

  @override
  bool shouldRepaint(_ZecPainter old) =>
      old.discColor != discColor || old.zColor != zColor;
}
