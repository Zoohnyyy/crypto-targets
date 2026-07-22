import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Plain solid background for every screen. (Name kept for import stability;
/// no gradient or glow — just the flat charcoal/light background color.)
class SpaceBackground extends StatelessWidget {
  const SpaceBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// A flat, solid card with a single hairline border. (Name kept for import
/// stability; no blur or translucency.)
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final radius = BorderRadius.circular(borderRadius);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: AppColors.card(brightness),
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppColors.border(brightness)),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A solid accent-filled pill button. (Name kept for import stability; solid
/// fill, no gradient or glow.)
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.height = 52,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: height,
          child: Center(
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
