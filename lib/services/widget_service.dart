import 'package:home_widget/home_widget.dart';

import '../models/coin.dart';

/// Pushes price data into the native Android home screen widget.
///
/// The Kotlin widget provider (CryptoWidgetProvider) reads these keys via
/// HomeWidgetPlugin's SharedPreferences and renders up to 4 rows.
class WidgetService {
  static const String _androidWidgetName = 'CryptoWidgetProvider';

  /// Write up to 4 coins' prices to the widget and trigger a redraw.
  static Future<void> update(
    List<Coin> watchlist,
    Map<String, PriceTick> prices,
  ) async {
    final rows = watchlist.take(4).toList();

    for (var i = 0; i < 4; i++) {
      if (i < rows.length) {
        final coin = rows[i];
        final tick = prices[coin.symbol];
        await HomeWidget.saveWidgetData<String>(
            'w_ticker_$i', coin.ticker);
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

    await HomeWidget.saveWidgetData<String>(
      'w_updated',
      _formatTime(DateTime.now()),
    );

    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
    );
  }

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
