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

  /// Persist coin stats (logos + 7d/30d change) so they show instantly on the
  /// next launch, even before CoinGecko responds (or if it's rate-limited).
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
  Coin(symbol: 'btc', name: 'Bitcoin', coingeckoId: 'bitcoin'),
  Coin(symbol: 'eth', name: 'Ethereum', coingeckoId: 'ethereum'),
  Coin(symbol: 'bnb', name: 'BNB', coingeckoId: 'binancecoin'),
  Coin(symbol: 'sol', name: 'Solana', coingeckoId: 'solana'),
  Coin(symbol: 'xrp', name: 'XRP', coingeckoId: 'ripple'),
  Coin(symbol: 'trx', name: 'TRON', coingeckoId: 'tron'),
  Coin(symbol: 'hype', name: 'Hyperliquid', coingeckoId: 'hyperliquid', exchange: Exchange.bybit),
  Coin(symbol: 'doge', name: 'Dogecoin', coingeckoId: 'dogecoin'),
  Coin(symbol: 'zec', name: 'Zcash', coingeckoId: 'zcash'),
  Coin(symbol: 'xlm', name: 'Stellar', coingeckoId: 'stellar'),
  Coin(symbol: 'ada', name: 'Cardano', coingeckoId: 'cardano'),
  Coin(symbol: 'link', name: 'Chainlink', coingeckoId: 'chainlink'),
  Coin(symbol: 'bch', name: 'Bitcoin Cash', coingeckoId: 'bitcoin-cash'),
  Coin(symbol: 'ltc', name: 'Litecoin', coingeckoId: 'litecoin'),
  Coin(symbol: 'sui', name: 'Sui', coingeckoId: 'sui'),
  Coin(symbol: 'hbar', name: 'Hedera', coingeckoId: 'hedera-hashgraph'),
  Coin(symbol: 'avax', name: 'Avalanche', coingeckoId: 'avalanche-2'),
  Coin(symbol: 'near', name: 'NEAR Protocol', coingeckoId: 'near'),
  Coin(symbol: 'shib', name: 'Shiba Inu', coingeckoId: 'shiba-inu'),
  Coin(symbol: 'uni', name: 'Uniswap', coingeckoId: 'uniswap'),
  Coin(symbol: 'ondo', name: 'Ondo', coingeckoId: 'ondo-finance'),
  Coin(symbol: 'tao', name: 'Bittensor', coingeckoId: 'bittensor'),
  Coin(symbol: 'wlfi', name: 'World Liberty Financial', coingeckoId: 'world-liberty-financial'),
  Coin(symbol: 'aster', name: 'Aster', coingeckoId: 'aster-2'),
  Coin(symbol: 'htx', name: 'HTX DAO', coingeckoId: 'htx-dao', exchange: Exchange.bybit),
  Coin(symbol: 'sky', name: 'Sky', coingeckoId: 'sky'),
  Coin(symbol: 'aave', name: 'Aave', coingeckoId: 'aave'),
  Coin(symbol: 'dot', name: 'Polkadot', coingeckoId: 'polkadot'),
  Coin(symbol: 'mnt', name: 'Mantle', coingeckoId: 'mantle', exchange: Exchange.bybit),
  Coin(symbol: 'wld', name: 'Worldcoin', coingeckoId: 'worldcoin-wld'),
  Coin(symbol: 'morpho', name: 'Morpho', coingeckoId: 'morpho'),
  Coin(symbol: 'pepe', name: 'Pepe', coingeckoId: 'pepe'),
  Coin(symbol: 'icp', name: 'Internet Computer', coingeckoId: 'internet-computer'),
  Coin(symbol: 'etc', name: 'Ethereum Classic', coingeckoId: 'ethereum-classic'),
  Coin(symbol: 'dexe', name: 'DeXe', coingeckoId: 'dexe'),
  Coin(symbol: 'qnt', name: 'Quant', coingeckoId: 'quant-network'),
  Coin(symbol: 'kcs', name: 'KuCoin', coingeckoId: 'kucoin-shares', exchange: Exchange.bybit),
  Coin(symbol: 'pol', name: 'POL (ex-MATIC)', coingeckoId: 'polygon-ecosystem-token'),
  Coin(symbol: 'jst', name: 'JUST', coingeckoId: 'just'),
  Coin(symbol: 'ena', name: 'Ethena', coingeckoId: 'ethena'),
  Coin(symbol: 'pump', name: 'Pump.fun', coingeckoId: 'pump-fun'),
  Coin(symbol: 'render', name: 'Render', coingeckoId: 'render-token'),
  Coin(symbol: 'kas', name: 'Kaspa', coingeckoId: 'kaspa', exchange: Exchange.bybit),
  Coin(symbol: 'atom', name: 'Cosmos', coingeckoId: 'cosmos'),
  Coin(symbol: 'nexo', name: 'NEXO', coingeckoId: 'nexo'),
  Coin(symbol: 'algo', name: 'Algorand', coingeckoId: 'algorand'),
  Coin(symbol: 'jup', name: 'Jupiter', coingeckoId: 'jupiter-exchange-solana'),
  Coin(symbol: 'fil', name: 'Filecoin', coingeckoId: 'filecoin'),
  Coin(symbol: 'arb', name: 'Arbitrum', coingeckoId: 'arbitrum'),
  Coin(symbol: 'xdc', name: 'XDC Network', coingeckoId: 'xdce-crowd-sale', exchange: Exchange.bybit),
  Coin(symbol: 'flr', name: 'Flare', coingeckoId: 'flare-networks', exchange: Exchange.bybit),
  Coin(symbol: 'inj', name: 'Injective', coingeckoId: 'injective-protocol'),
  // Popular coins just outside the current top 100 (kept for continuity).
  Coin(symbol: 'apt', name: 'Aptos', coingeckoId: 'aptos'),
  Coin(symbol: 'op', name: 'Optimism', coingeckoId: 'optimism'),
  Coin(symbol: 'sei', name: 'Sei', coingeckoId: 'sei-network'),
];

/// The initial watchlist for a fresh install.
const List<Coin> defaultWatchlist = [
  Coin(symbol: 'btc', name: 'Bitcoin', coingeckoId: 'bitcoin'),
  Coin(symbol: 'eth', name: 'Ethereum', coingeckoId: 'ethereum'),
  Coin(symbol: 'sol', name: 'Solana', coingeckoId: 'solana'),
  Coin(symbol: 'bnb', name: 'BNB', coingeckoId: 'binancecoin'),
];

/// Resolve a friendly name for a base symbol, falling back to the ticker.
String nameForSymbol(String symbol) {
  final lower = symbol.toLowerCase();
  for (final c in coinCatalog) {
    if (c.symbol == lower) return c.name;
  }
  return symbol.toUpperCase();
}

/// Resolve the CoinGecko id for a base symbol from the catalog, or null if the
/// coin isn't in our curated list.
String? coingeckoIdForSymbol(String symbol) {
  final lower = symbol.toLowerCase();
  for (final c in coinCatalog) {
    if (c.symbol == lower) return c.coingeckoId;
  }
  return null;
}
