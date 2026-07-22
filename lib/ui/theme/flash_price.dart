import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Displays a price string that briefly flashes green (up) or red (down)
/// whenever the underlying [price] changes — like professional trading apps.
class FlashPrice extends StatefulWidget {
  const FlashPrice({
    super.key,
    required this.price,
    required this.text,
    this.style,
  });

  /// The raw price used to detect up/down movement.
  final double? price;

  /// The formatted text to display.
  final String text;

  final TextStyle? style;

  @override
  State<FlashPrice> createState() => _FlashPriceState();
}

class _FlashPriceState extends State<FlashPrice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double? _lastPrice;
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    _lastPrice = widget.price;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didUpdateWidget(FlashPrice old) {
    super.didUpdateWidget(old);
    final now = widget.price;
    final prev = _lastPrice;
    if (now != null && prev != null && now != prev) {
      _flashColor = now > prev ? AppColors.green : AppColors.red;
      _controller.forward(from: 0);
    }
    _lastPrice = now;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
    final baseColor = baseStyle.color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.white;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = 1 - _controller.value; // 1 at flash start, 0 when settled
        final color = _flashColor == null
            ? baseColor
            : Color.lerp(baseColor, _flashColor, t);
        return Text(widget.text, style: baseStyle.copyWith(color: color));
      },
    );
  }
}
