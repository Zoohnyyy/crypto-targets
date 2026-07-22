import '../models/coin.dart';
import '../models/portfolio.dart';
import '../models/portfolio_alert.dart';
import '../models/price_alert.dart';

/// Pure helpers for valuing a portfolio. Shared by the UI and the background
/// isolate so both compute values identically.
class PortfolioMath {
  PortfolioMath._();

  /// Total USD value of the portfolio given a map of symbol -> USD price.
  /// Holdings whose price is missing contribute 0.
  static double usdValue(Portfolio p, Map<String, double> prices) {
    var total = 0.0;
    for (final h in p.holdings) {
      final price = prices[h.symbol];
      if (price != null) total += h.amount * price;
    }
    return total;
  }

  /// Portfolio value expressed in units of [denomSymbol]'s token, i.e.
  /// (portfolio USD) / (denom token USD price). Returns null if the denom
  /// price is unavailable or zero.
  static double? valueInToken(
    Portfolio p,
    Map<String, double> prices,
    String denomSymbol,
  ) {
    final denomPrice = prices[denomSymbol.toLowerCase()];
    if (denomPrice == null || denomPrice == 0) return null;
    return usdValue(p, prices) / denomPrice;
  }

  /// The portfolio value in the alert's own denomination, or null if it can't
  /// be computed yet (missing denom price).
  static double? valueForAlert(
    Portfolio p,
    Map<String, double> prices,
    PortfolioAlert alert,
  ) {
    if (alert.denom == AlertDenom.usd) return usdValue(p, prices);
    final sym = alert.denomSymbol;
    if (sym == null) return null;
    return valueInToken(p, prices, sym);
  }

  /// Build the set of coins that need USD prices to evaluate the portfolio and
  /// its alerts: every holding token plus every alert denomination token.
  static List<Coin> requiredCoins(
    Portfolio p,
    List<PortfolioAlert> alerts, {
    required Coin Function(String symbol) resolve,
  }) {
    final symbols = <String>{...p.symbols};
    for (final a in alerts) {
      if (a.denom == AlertDenom.token && a.denomSymbol != null) {
        symbols.add(a.denomSymbol!.toLowerCase());
      }
    }
    return symbols.map(resolve).toList();
  }
}

/// Format a portfolio-alert target/value for display, given its denomination.
String formatDenomValue(double value, AlertDenom denom, String? symbol) {
  if (denom == AlertDenom.usd) {
    return '\$${_thousands(value, 2)}';
  }
  final ticker = (symbol ?? '').toUpperCase();
  // Token amounts: show more precision for small numbers.
  final digits = value >= 1000 ? 2 : (value >= 1 ? 4 : 6);
  return '${_thousands(value, digits)} $ticker';
}

String _thousands(double v, int digits) {
  final fixed = v.toStringAsFixed(digits);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  final neg = intPart.startsWith('-');
  final digitsOnly = neg ? intPart.substring(1) : intPart;
  for (var i = 0; i < digitsOnly.length; i++) {
    if (i > 0 && (digitsOnly.length - i) % 3 == 0) buf.write(',');
    buf.write(digitsOnly[i]);
  }
  final grouped = (neg ? '-' : '') + buf.toString();
  return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
}

/// Re-exported for convenience where only direction is needed.
typedef Direction = AlertDirection;
