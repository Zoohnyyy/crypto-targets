import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/coin.dart';
import '../models/coin_stats.dart';
import '../models/portfolio.dart';
import '../models/portfolio_alert.dart';
import '../models/price_alert.dart';

/// Persists the user's watchlist and alerts to [SharedPreferences].
///
/// Keys are also read by the background isolate (WorkManager) and, indirectly,
/// by the native home widget via cached price values.
class StorageService {
  static const _kWatchlist = 'watchlist_v1';
  static const _kAlerts = 'alerts_v1';
  static const _kPortfolio = 'portfolio_v1';
  static const _kPortfolioAlerts = 'portfolio_alerts_v1';
  static const _kHideBalances = 'hide_balances_v1';

  /// Cached last-known prices, JSON map of symbol -> {price, change}.
  /// Written by both the UI and background tasks; read by the widget.
  static const kCachedPrices = 'cached_prices_v1';

  Future<List<Coin>> loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kWatchlist);
    if (raw == null) return List<Coin>.from(defaultWatchlist);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Coin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveWatchlist(List<Coin> coins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kWatchlist,
      jsonEncode(coins.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<PriceAlert>> loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAlerts);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PriceAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAlerts(List<PriceAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kAlerts,
      jsonEncode(alerts.map((a) => a.toJson()).toList()),
    );
  }

  // ---- Portfolio ---------------------------------------------------------

  Future<Portfolio> loadPortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPortfolio);
    if (raw == null) return const Portfolio();
    return Portfolio.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> savePortfolio(Portfolio portfolio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPortfolio, jsonEncode(portfolio.toJson()));
  }

  Future<List<PortfolioAlert>> loadPortfolioAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPortfolioAlerts);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PortfolioAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePortfolioAlerts(List<PortfolioAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPortfolioAlerts,
      jsonEncode(alerts.map((a) => a.toJson()).toList()),
    );
  }

  // ---- Privacy -----------------------------------------------------------

  /// Whether balances (portfolio total, holding amounts/values) are masked.
  /// Read by the background isolate too, so the widget stays hidden while the
  /// app isn't running.
  Future<bool> loadHideBalances() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kHideBalances) ?? false;
  }

  Future<void> saveHideBalances(bool hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHideBalances, hidden);
  }

  /// Persist the latest prices so the widget and background tasks can read them
  /// without a live socket.
  static Future<void> cachePrices(Map<String, PriceTick> prices) async {
    final prefs = await SharedPreferences.getInstance();
    final map = prices.map((k, v) => MapEntry(k, {
          'price': v.price,
          'change': v.changePercent,
        }));
    await prefs.setString(kCachedPrices, jsonEncode(map));
  }

  static Future<Map<String, PriceTick>> loadCachedPrices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kCachedPrices);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) {
      final m = v as Map<String, dynamic>;
      return MapEntry(
        k,
        PriceTick(
          symbol: k,
          price: (m['price'] as num).toDouble(),
          changePercent: (m['change'] as num).toDouble(),
        ),
      );
    });
  }

  static const _kCachedStats = 'cached_stats_v1';

  /// Persist coin stats (logos + multi-day changes) so they show instantly on
  /// the next launch, before the exchanges have answered. Logos in particular
  /// are only ever looked up for coins the cache has none for.
  static Future<void> cacheStats(Map<String, CoinStats> stats) async {
    final prefs = await SharedPreferences.getInstance();
    final map = stats.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_kCachedStats, jsonEncode(map));
  }

  static Future<Map<String, CoinStats>> loadCachedStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCachedStats);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(k, CoinStats.fromJson(v as Map<String, dynamic>)),
    );
  }
}

/// A curated catalog of popular coins available as Binance USDT pairs.
/// Used to seed the watchlist and power the "add coin" search UI with names.
const List<Coin> coinCatalog = [
  Coin(symbol: 'btc', name: 'Bitcoin'),
  Coin(symbol: 'eth', name: 'Ethereum'),
  // The quote asset itself: holdable and usable as an alert denomination, but
  // it has no pair to price or chart, so it never reaches the exchanges.
  Coin(symbol: 'usdt', name: 'Tether', exchange: Exchange.none),
  Coin(symbol: 'bnb', name: 'BNB'),
  Coin(symbol: 'sol', name: 'Solana'),
  Coin(symbol: 'xrp', name: 'XRP'),
  Coin(symbol: 'trx', name: 'TRON'),
  Coin(symbol: 'hype', name: 'Hyperliquid', exchange: Exchange.bybit),
  Coin(symbol: 'doge', name: 'Dogecoin'),
  Coin(symbol: 'zec', name: 'Zcash'),
  Coin(symbol: 'xlm', name: 'Stellar'),
  Coin(symbol: 'ada', name: 'Cardano'),
  Coin(symbol: 'link', name: 'Chainlink'),
  Coin(symbol: 'bch', name: 'Bitcoin Cash'),
  Coin(symbol: 'ltc', name: 'Litecoin'),
  Coin(symbol: 'sui', name: 'Sui'),
  Coin(symbol: 'hbar', name: 'Hedera'),
  Coin(symbol: 'avax', name: 'Avalanche'),
  Coin(symbol: 'near', name: 'NEAR Protocol'),
  Coin(symbol: 'shib', name: 'Shiba Inu'),
  Coin(symbol: 'uni', name: 'Uniswap'),
  Coin(symbol: 'ondo', name: 'Ondo'),
  Coin(symbol: 'tao', name: 'Bittensor'),
  Coin(symbol: 'wlfi', name: 'World Liberty Financial'),
  Coin(symbol: 'aster', name: 'Aster'),
  Coin(symbol: 'htx', name: 'HTX DAO', exchange: Exchange.bybit),
  Coin(symbol: 'sky', name: 'Sky'),
  Coin(symbol: 'aave', name: 'Aave'),
  Coin(symbol: 'dot', name: 'Polkadot'),
  Coin(symbol: 'mnt', name: 'Mantle', exchange: Exchange.bybit),
  Coin(symbol: 'wld', name: 'Worldcoin'),
  Coin(symbol: 'morpho', name: 'Morpho'),
  Coin(symbol: 'pepe', name: 'Pepe'),
  Coin(symbol: 'icp', name: 'Internet Computer'),
  Coin(symbol: 'etc', name: 'Ethereum Classic'),
  Coin(symbol: 'dexe', name: 'DeXe'),
  Coin(symbol: 'qnt', name: 'Quant'),
  Coin(symbol: 'kcs', name: 'KuCoin', exchange: Exchange.bybit),
  Coin(symbol: 'pol', name: 'POL (ex-MATIC)'),
  Coin(symbol: 'jst', name: 'JUST'),
  Coin(symbol: 'ena', name: 'Ethena'),
  Coin(symbol: 'pump', name: 'Pump.fun'),
  Coin(symbol: 'render', name: 'Render'),
  Coin(symbol: 'kas', name: 'Kaspa', exchange: Exchange.bybit),
  Coin(symbol: 'atom', name: 'Cosmos'),
  Coin(symbol: 'nexo', name: 'NEXO'),
  Coin(symbol: 'algo', name: 'Algorand'),
  Coin(symbol: 'jup', name: 'Jupiter'),
  Coin(symbol: 'fil', name: 'Filecoin'),
  Coin(symbol: 'arb', name: 'Arbitrum'),
  Coin(symbol: 'xdc', name: 'XDC Network', exchange: Exchange.bybit),
  Coin(symbol: 'flr', name: 'Flare', exchange: Exchange.bybit),
  Coin(symbol: 'inj', name: 'Injective'),
  // Popular coins just outside the current top 100 (kept for continuity).
  Coin(symbol: 'apt', name: 'Aptos'),
  Coin(symbol: 'op', name: 'Optimism'),
  Coin(symbol: 'sei', name: 'Sei'),
];

/// The initial watchlist for a fresh install.
const List<Coin> defaultWatchlist = [
  Coin(symbol: 'btc', name: 'Bitcoin'),
  Coin(symbol: 'eth', name: 'Ethereum'),
  Coin(symbol: 'sol', name: 'Solana'),
  Coin(symbol: 'bnb', name: 'BNB'),
];

/// Resolve a friendly name for a base symbol, falling back to the ticker.
String nameForSymbol(String symbol) {
  final lower = symbol.toLowerCase();
  for (final c in coinCatalog) {
    if (c.symbol == lower) return c.name;
  }
  return symbol.toUpperCase();
}

