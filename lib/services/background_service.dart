import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../models/coin.dart';
import '../models/portfolio.dart';
import '../models/portfolio_alert.dart';
import '../models/price_alert.dart';
import 'binance_service.dart';
import 'bybit_service.dart';
import 'notification_service.dart';
import 'portfolio_math.dart';
import 'storage_service.dart';
import 'widget_service.dart';

/// Names of the periodic background tasks.
const String kRefreshTask = 'crypto_refresh_task';

/// Entry point invoked by WorkManager in a background isolate.
///
/// Must be a top-level or static function annotated with @pragma so it survives
/// tree-shaking in release builds.
@pragma('vm:entry-point')
void callbackDispatcher() {
  // The background isolate has its own binding; it must be initialised before
  // any plugin channel call (shared_preferences, home_widget, notifications),
  // otherwise those calls throw "ServicesBinding not initialised".
  WidgetsFlutterBinding.ensureInitialized();

  Workmanager().executeTask((task, inputData) async {
    try {
      await _runRefresh();
      return true;
    } catch (_) {
      // A transient failure (e.g. no network) returns false so WorkManager
      // retries with its own backoff instead of waiting a full period.
      return false;
    }
  });
}

/// Fetch a fresh snapshot, update the widget, and evaluate price alerts.
/// Shared by the periodic task and the one-off warm-up task.
Future<void> _runRefresh() async {
  final storage = StorageService();
  final watchlist = await storage.loadWatchlist();
  final portfolio = await storage.loadPortfolio();
  final portfolioAlerts = await storage.loadPortfolioAlerts();
  final hideBalances = await storage.loadHideBalances();

  // Every token we need a price for: watchlist + portfolio holdings +
  // alert-denomination tokens.
  final coins = <String, Coin>{for (final c in watchlist) c.symbol: c};
  for (final c in PortfolioMath.requiredCoins(portfolio, portfolioAlerts,
      resolve: _resolveCoin)) {
    coins.putIfAbsent(c.symbol, () => c);
  }
  // Nothing needs a live price. A portfolio of only fixed-price holdings (an
  // all-USDT balance) still has a total worth showing, so refresh the widget
  // before bowing out.
  if (coins.isEmpty) {
    if (portfolio.holdings.isNotEmpty) {
      await WidgetService.update(
        watchlist,
        const {},
        portfolio: portfolio,
        hideBalances: hideBalances,
      );
    }
    return;
  }
  final coinList = coins.values.toList();

  // Fetch both exchanges in parallel; one failing shouldn't block the other.
  final results = await Future.wait([
    BinanceService.fetchSnapshot(coinList).catchError((_) => <PriceTick>[]),
    BybitService.fetchSnapshot(coinList).catchError((_) => <PriceTick>[]),
  ]);
  final priceMap = <String, PriceTick>{};
  for (final ticks in results) {
    for (final t in ticks) {
      priceMap[t.symbol] = t;
    }
  }
  // If every source failed we have nothing to persist; let WorkManager retry.
  if (priceMap.isEmpty) throw Exception('No prices fetched');

  // Persist for the in-app view and the widget.
  await StorageService.cachePrices(priceMap);
  await WidgetService.update(
    watchlist,
    priceMap,
    portfolio: portfolio,
    hideBalances: hideBalances,
  );

  await _evaluateAlerts(storage, priceMap);
  await _evaluatePortfolioAlerts(storage, portfolio, priceMap);
}

/// Resolve a symbol to a [Coin] using the catalog (correct exchange routing),
/// falling back to a Binance coin.
Coin _resolveCoin(String symbol) {
  final lower = symbol.toLowerCase();
  for (final c in coinCatalog) {
    if (c.symbol == lower) return c;
  }
  return Coin(symbol: lower, name: lower.toUpperCase());
}

/// Evaluate portfolio-value alerts (USD or token-denominated) and fire
/// notifications on crossing, with the same edge-trigger + re-arm logic.
Future<void> _evaluatePortfolioAlerts(
  StorageService storage,
  Portfolio portfolio,
  Map<String, PriceTick> ticks,
) async {
  final alerts = await storage.loadPortfolioAlerts();
  if (alerts.isEmpty) return;

  final prices = {for (final e in ticks.entries) e.key: e.value.price};
  var changed = false;

  for (final alert in alerts) {
    if (!alert.enabled) continue;
    final value = PortfolioMath.valueForAlert(portfolio, prices, alert);
    if (value == null) continue; // missing price; skip this cycle

    final met = alert.isMet(value);
    if (met && !alert.triggered) {
      alert.triggered = true;
      changed = true;
      await NotificationService.instance.showPriceAlert(
        id: alert.id.hashCode & 0x7fffffff,
        title: 'Portfolio alert',
        body: _portfolioAlertBody(alert, value),
      );
    } else if (!met && alert.triggered) {
      alert.triggered = false;
      changed = true;
    }
  }

  if (changed) await storage.savePortfolioAlerts(alerts);
}

String _portfolioAlertBody(PortfolioAlert alert, double value) {
  final dir = alert.direction == AlertDirection.above ? 'above' : 'below';
  final now = formatDenomValue(value, alert.denom, alert.denomSymbol);
  final target =
      formatDenomValue(alert.targetAmount, alert.denom, alert.denomSymbol);
  return 'Your portfolio is now $now — $dir your target of $target';
}

/// Check every enabled alert against the latest prices and fire notifications.
///
/// Uses a simple edge-trigger: an alert fires once when its condition first
/// becomes true, and re-arms only after the price moves back across the
/// threshold. This avoids repeat spam every 15 minutes.
Future<void> _evaluateAlerts(
  StorageService storage,
  Map<String, PriceTick> prices,
) async {
  final alerts = await storage.loadAlerts();
  if (alerts.isEmpty) return;

  var changed = false;

  for (final alert in alerts) {
    if (!alert.enabled) continue;
    final tick = prices[alert.symbol];
    if (tick == null) continue;

    final met = alert.isMet(tick.price);

    if (met && !alert.triggered) {
      alert.triggered = true;
      changed = true;
      await NotificationService.instance.showPriceAlert(
        id: alert.id.hashCode & 0x7fffffff,
        title: '${alert.symbol.toUpperCase()} price alert',
        body: _alertBody(alert, tick.price),
      );
    } else if (!met && alert.triggered) {
      // Re-arm once price crosses back.
      alert.triggered = false;
      changed = true;
    }
  }

  if (changed) await storage.saveAlerts(alerts);
}

String _alertBody(PriceAlert alert, double price) {
  final dir = alert.direction == AlertDirection.above ? 'above' : 'below';
  final target = alert.targetPrice >= 1
      ? alert.targetPrice.toStringAsFixed(2)
      : alert.targetPrice.toStringAsFixed(6);
  final now = price >= 1 ? price.toStringAsFixed(2) : price.toStringAsFixed(6);
  return '${alert.symbol.toUpperCase()} is now \$$now — $dir your target of \$$target';
}

/// Registers the periodic background refresh. 15 minutes is the Android minimum.
class BackgroundService {
  static Future<void> initialise() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<void> registerPeriodicRefresh() async {
    await Workmanager().registerPeriodicTask(
      kRefreshTask,
      kRefreshTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  /// Fire a one-off refresh right now (e.g. after the user edits alerts or the
  /// watchlist) so the widget/alerts don't wait up to 15 minutes.
  static Future<void> refreshNow() async {
    await Workmanager().registerOneOffTask(
      'crypto_refresh_once_${DateTime.now().millisecondsSinceEpoch}',
      kRefreshTask,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
