import 'package:intl/intl.dart';

/// Formatting helpers shared across the UI.

final NumberFormat _big = NumberFormat('#,##0.00', 'en_US');
final NumberFormat _mid = NumberFormat('#,##0.0000', 'en_US');
final NumberFormat _small = NumberFormat('#,##0.00000000', 'en_US');

/// Format a USD price with sensible precision based on magnitude.
String formatUsd(double price) {
  if (price >= 1) return '\$${_big.format(price)}';
  if (price >= 0.01) return '\$${_mid.format(price)}';
  return '\$${_small.format(price)}';
}

/// Format a 24h change percentage with sign, e.g. "+1.23%".
String formatChange(double pct) {
  final sign = pct >= 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(2)}%';
}
