import 'package:home_widget/home_widget.dart';

import '../models/coin.dart';
import '../models/portfolio.dart';
import '../models/portfolio_alert.dart';
import 'portfolio_math.dart';

/// Pushes data into the native Android home screen widgets.
///
/// Two widgets are fed from here, both reading the keys written below via
/// HomeWidgetPlugin's SharedPreferences:
///  * CryptoWidgetProvider — up to 4 watchlist coins with price + 24h change.
///  * PortfolioWidgetProvider — a single 4x1 row: total portfolio value and
///    its 24h change.
class WidgetService {
  static const String _priceWidgetName = 'CryptoWidgetProvider';
  static const String _portfolioWidgetName = 'PortfolioWidgetProvider';

  /// Number of rows the watchlist widget layout has room for.
  static const int _priceRows = 4;

  /// Write the latest watchlist prices and portfolio value to both widgets and
  /// trigger a redraw.
  ///
  /// [hideBalances] mirrors the in-app privacy setting: the widget sits in the
  /// open on the home screen, so it masks the total the same way.
  static Future<void> update(
    List<Coin> watchlist,
    Map<String, PriceTick> prices, {
    Portfolio portfolio = const Portfolio(),
    bool hideBalances = false,
  }) async {
    await _writePrices(watchlist, prices);
    await _writePortfolio(portfolio, prices, hideBalances);

    await HomeWidget.saveWidgetData<String>(
      'w_updated',
      _formatTime(DateTime.now()),
    );

    await HomeWidget.updateWidget(androidName: _priceWidgetName);
    await HomeWidget.updateWidget(androidName: _portfolioWidgetName);
  }

  // ---- Watchlist widget ----------------------------------------------------

  static Future<void> _writePrices(
    List<Coin> watchlist,
    Map<String, PriceTick> prices,
  ) async {
    final rows = watchlist.take(_priceRows).toList();

    for (var i = 0; i < _priceRows; i++) {
      if (i < rows.length) {
        final coin = rows[i];
        final tick = prices[coin.symbol];
        await HomeWidget.saveWidgetData<String>('w_ticker_$i', coin.ticker);
        await HomeWidget.saveWidgetData<String>(
          'w_price_$i',
          tick != null ? _formatPrice(tick.price) : '—',
        );
        await HomeWidget.saveWidgetData<String>(
          'w_change_$i',
          tick != null ? _formatChange(tick.changePercent) : '',
        );
      } else {
        await HomeWidget.saveWidgetData<String>('w_ticker_$i', '');
        await HomeWidget.saveWidgetData<String>('w_price_$i', '');
        await HomeWidget.saveWidgetData<String>('w_change_$i', '');
      }
    }
  }

  // ---- Portfolio widget ----------------------------------------------------

  /// The portfolio widget is a single 4x1 row, so only the headline figures
  /// are written: total value and the blended 24h change.
  static Future<void> _writePortfolio(
    Portfolio portfolio,
    Map<String, PriceTick> prices,
    bool hideBalances,
  ) async {
    final priceMap = {for (final e in prices.entries) e.key: e.value.price};
    final total = PortfolioMath.usdValue(portfolio, priceMap);

    await HomeWidget.saveWidgetData<String>(
      'w_pf_total',
      maskIfHidden(formatDenomValue(total, AlertDenom.usd, null), hideBalances),
    );
    // The percentage reveals nothing about the balance, so it stays visible
    // even when the total is masked.
    await HomeWidget.saveWidgetData<String>(
      'w_pf_change',
      _portfolioChangeLabel(portfolio, prices),
    );
    // Lets the native side show an explanatory placeholder instead of "$0.00".
    await HomeWidget.saveWidgetData<String>(
      'w_pf_empty',
      portfolio.holdings.isEmpty ? '1' : '0',
    );
  }

  /// The portfolio's own 24h change, derived from each holding's 24h percentage.
  ///
  /// Each coin's price 24h ago is backed out of its current price and change
  /// (`prev = price / (1 + pct/100)`), giving the portfolio's value then; the
  /// two totals produce a blended change. Returns an empty string when nothing
  /// can be valued, so the widget hides the field.
  static String _portfolioChangeLabel(
    Portfolio portfolio,
    Map<String, PriceTick> prices,
  ) {
    var now = 0.0;
    var before = 0.0;

    for (final h in portfolio.holdings) {
      final tick = prices[h.symbol];
      if (tick == null) {
        // A fixed-price holding (USDT) has no tick, but it does hold value and
        // it didn't move: counting it on both sides correctly damps the
        // portfolio's overall percentage instead of inflating it.
        final fixed = fixedUsdPrice(h.symbol);
        if (fixed == null) continue;
        now += h.amount * fixed;
        before += h.amount * fixed;
        continue;
      }
      final factor = 1 + tick.changePercent / 100;
      // A -100% move (or bad data) would divide by zero; skip that holding.
      if (factor <= 0) continue;
      now += h.amount * tick.price;
      before += h.amount * (tick.price / factor);
    }

    if (before <= 0) return '';
    return _formatChange((now - before) / before * 100);
  }

  // ---- Formatting ----------------------------------------------------------

  static String _formatPrice(double price) {
    if (price >= 1000) return '\$${price.toStringAsFixed(0)}';
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    return '\$${price.toStringAsFixed(6)}';
  }

  static String _formatChange(double pct) {
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(2)}%';
  }

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }
}
