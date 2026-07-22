import 'package:flutter/material.dart';

/// Central design system: a clean, solid, no-gradient look.
///
/// Emerald accent on a charcoal (near-black) background, with flat cards and a
/// single hairline border. Green/red are reserved for market up/down.
class AppColors {
  AppColors._();

  /// The single brand accent.
  static const accent = Color(0xFF2EBD85); // emerald
  static const accentDim = Color(0xFF1F8F65);

  // Market colors.
  static const green = Color(0xFF2EBD85);
  static const red = Color(0xFFE5484D);

  // Charcoal backgrounds (dark).
  static const bgDark = Color(0xFF0E0F13);
  static const cardDark = Color(0xFF181A20);
  static const borderDark = Color(0xFF262930);

  // Light-mode surfaces.
  static const bgLight = Color(0xFFF6F7F9);
  static const cardLight = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE3E6EB);

  // Text.
  static const textDark = Color(0xFFF4F5F7);
  static const textLight = Color(0xFF16181D);

  static Color background(Brightness b) =>
      b == Brightness.dark ? bgDark : bgLight;

  static Color card(Brightness b) =>
      b == Brightness.dark ? cardDark : cardLight;

  static Color border(Brightness b) =>
      b == Brightness.dark ? borderDark : borderLight;

  static Color text(Brightness b) =>
      b == Brightness.dark ? textDark : textLight;

  /// Muted/secondary text color.
  static Color muted(Brightness b) => (b == Brightness.dark
          ? const Color(0xFFF4F5F7)
          : const Color(0xFF16181D))
      .withValues(alpha: 0.5);
}

class AppTheme {
  static ThemeData build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.accent,
      surface: AppColors.card(brightness),
      onSurface: AppColors.text(brightness),
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background(brightness),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.text(brightness),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.text(brightness)),
      ),
      fontFamily: 'Roboto',
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.accent.withValues(alpha: 0.4)
                : null),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text(brightness),
        displayColor: AppColors.text(brightness),
      ),
      dividerColor: AppColors.border(brightness),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.text(brightness),
        unselectedLabelColor: AppColors.muted(brightness),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 2.5, color: AppColors.accent),
          insets: EdgeInsets.symmetric(horizontal: 28),
        ),
      ),
    );
  }
}
