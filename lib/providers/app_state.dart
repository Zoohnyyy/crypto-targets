import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/coin.dart';
import '../models/coin_stats.dart';
import '../models/portfolio.dart';
import '../models/portfolio_alert.dart';
import '../models/price_alert.dart';
import '../services/backend_sync.dart';
import '../services/background_service.dart';
import '../services/binance_service.dart';
import '../services/bybit_service.dart';
import '../services/coingecko_service.dart';
import '../services/portfolio_math.dart';
import '../services/push_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';

/// Central app state: watchlist, live prices, and alerts.
///
/// Owns the live price sockets (Binance for most coins, Bybit for the few not
/// listed on Binance such as HYPE) and mirrors data into persistent storage +
/// the home widget as prices arrive.
class AppState extends ChangeNotifier {
  AppState({
    StorageService? storage,
    BinanceService? binance,
    BybitService? bybit,
  })  : _storage = storage ?? StorageService(),
        _binance = binance ?? BinanceService(),
        _bybit = bybit ?? BybitService();

  final StorageService _storage;
  final BinanceService _binance;
  final BybitService _bybit;

  List<Coin> _watchlist = [];
  final Map<String, PriceTick> _prices = {};
  final Map<String, CoinStats> _stats = {};
  List<PriceAlert> _alerts = [];
  Portfolio _portfolio = const Portfolio();
  List<PortfolioAlert> _portfolioAlerts = [];
  bool _loading = true;
  StreamSubscription<PriceTick>? _tickSub;
  StreamSubscription<PriceTick>? _bybitTickSub;
  Timer? _statsTimer;

  // Throttle widget writes so we don't hammer SharedPreferences on every tick.
  DateTime _lastWidgetPush = DateTime.fromMillisecondsSinceEpoch(0);

  List<Coin> get watchlist => List.unmodifiable(_watchlist);
  List<PriceAlert> get alerts => List.unmodifiable(_alerts);
  Portfolio get portfolio => _portfolio;
  List<PortfolioAlert> get portfolioAlerts =>
      List.unmodifiable(_portfolioAlerts);
  bool get loading => _loading;

  PriceTick? priceFor(String symbol) => _prices[symbol];

  /// Extended stats (logo + 7d/30d change) for a coin, if fetched yet.
  CoinStats? statsFor(String symbol) => _stats[symbol];

  /// Current map of symbol -> USD price, from live/cached ticks.
  Map<String, double> get _priceMap =>
      {for (final e in _prices.entries) e.key: e.value.price};

  /// Live total USD value of the portfolio.
  double get portfolioUsdValue =>
      PortfolioMath.usdValue(_portfolio, _priceMap);

  /// Live portfolio value in units of [symbol]'s token, or null if unknown.
  double? portfolioValueInToken(String symbol) =>
      PortfolioMath.valueInToken(_portfolio, _priceMap, symbol);

  /// Live value for a portfolio alert in its own denomination.
  double? portfolioAlertValue(PortfolioAlert alert) =>
      PortfolioMath.valueForAlert(_portfolio, _priceMap, alert);

  Future<void> init() async {
    _watchlist = await _storage.loadWatchlist();
    _alerts = await _storage.loadAlerts();
    _portfolio = await _storage.loadPortfolio();
    _portfolioAlerts = await _storage.loadPortfolioAlerts();

    // Seed with cached prices + stats for instant display before the network
    // warms up (logos show immediately from the last successful fetch).
    _prices.addAll(await StorageService.loadCachedPrices());
    _stats.addAll(await StorageService.loadCachedStats());
    _loading = false;
    notifyListeners();

    // Pull a fresh REST snapshot immediately, then start streaming.
    unawaited(_primeSnapshot());
    _startStreaming();
    _startStatsPolling();

    // When the FCM token arrives (or refreshes), (re)sync the alert bundle to
    // the push backend so it can evaluate + push instantly.
    PushService.instance.onToken((_) => unawaited(_syncBackend()));
    unawaited(_syncBackend());
  }

  /// Upload the current alert definitions to the push backend (no-op unless
  /// push is configured and a token is available).
  Future<void> _syncBackend() async {
    await BackendSync.instance.sync(
      priceAlerts: _alerts,
      portfolio: _portfolio,
      portfolioAlerts: _portfolioAlerts,
    );
  }

  /// Poll CoinGecko for logos + 7d/30d change. Multi-day figures barely change
  /// minute to minute and the free API is rate-limited, so poll every 2 min.
  void _startStatsPolling() {
    _statsTimer?.cancel();
    unawaited(_refreshStats());
    _statsTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(_refreshStats()),
    );
  }

  Future<void> _refreshStats() async {
    try {
      final stats = await CoinGeckoService.fetchStats(_watchlist);
      if (stats.isEmpty) return;
      _stats.addAll(stats);
      notifyListeners();
      unawaited(StorageService.cacheStats(Map.of(_stats)));
    } catch (_) {
      // Rate limit / transient error: keep whatever we already have.
    }
  }

  /// Coins that need a live price: the watchlist plus any portfolio holdings
  /// and alert-denomination tokens not already on it (deduped by symbol).
  List<Coin> get _pricedCoins {
    final map = <String, Coin>{
      for (final c in _watchlist) c.symbol: c,
    };
    final extra = PortfolioMath.requiredCoins(
      _portfolio,
      _portfolioAlerts,
      resolve: _resolveCoin,
    );
    for (final c in extra) {
      map.putIfAbsent(c.symbol, () => c);
    }
    return map.values.toList();
  }

  /// Resolve a symbol to a [Coin] using the catalog (for correct exchange
  /// routing / name), falling back to a Binance coin.
  Coin _resolveCoin(String symbol) {
    final lower = symbol.toLowerCase();
    for (final c in coinCatalog) {
      if (c.symbol == lower) return c;
    }
    return Coin(symbol: lower, name: lower.toUpperCase());
  }

  Future<void> _primeSnapshot() async {
    final coins = _pricedCoins;
    // Fetch both exchanges in parallel; a failure of one shouldn't block the
    // other.
    final results = await Future.wait([
      BinanceService.fetchSnapshot(coins).catchError((_) => <PriceTick>[]),
      BybitService.fetchSnapshot(coins).catchError((_) => <PriceTick>[]),
    ]);
    for (final ticks in results) {
      for (final t in ticks) {
        _prices[t.symbol] = t;
      }
    }
    notifyListeners();
    unawaited(StorageService.cachePrices(Map.of(_prices)));
    unawaited(WidgetService.update(_watchlist, Map.of(_prices)));
  }

  void _startStreaming() {
    _tickSub?.cancel();
    _bybitTickSub?.cancel();

    final coins = _pricedCoins;
    _binance.subscribe(coins);
    _tickSub = _binance.ticks.listen(_onTick);

    _bybit.subscribe(coins);
    _bybitTickSub = _bybit.ticks.listen(_onTick);
  }

  void _onTick(PriceTick tick) {
    _prices[tick.symbol] = tick;
    _maybePushWidget();
    notifyListeners();
  }

  void _maybePushWidget() {
    final now = DateTime.now();
    if (now.difference(_lastWidgetPush) < const Duration(seconds: 30)) return;
    _lastWidgetPush = now;
    unawaited(StorageService.cachePrices(Map.of(_prices)));
    unawaited(WidgetService.update(_watchlist, Map.of(_prices)));
  }

  // ---- Watchlist editing -------------------------------------------------

  bool isWatched(String symbol) =>
      _watchlist.any((c) => c.symbol == symbol.toLowerCase());

  Future<void> addCoin(Coin coin) async {
    if (isWatched(coin.symbol)) return;
    _watchlist = [..._watchlist, coin];
    await _persistWatchlistAndRestream();
  }

  Future<void> removeCoin(String symbol) async {
    final lower = symbol.toLowerCase();
    _watchlist = _watchlist.where((c) => c.symbol != lower).toList();
    // Drop the cached price so a later re-add doesn't briefly show a stale
    // value from before removal.
    _prices.remove(lower);
    await _persistWatchlistAndRestream();
  }

  /// Reorder via ReorderableListView's [onReorderItem] callback, where
  /// [newIndex] is already the final target index (no manual adjustment).
  Future<void> reorderWatchlist(int oldIndex, int newIndex) async {
    final list = [..._watchlist];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _watchlist = list;
    await _persistWatchlistAndRestream();
  }

  Future<void> _persistWatchlistAndRestream() async {
    await _storage.saveWatchlist(_watchlist);
    notifyListeners();
    _startStreaming();
    unawaited(_primeSnapshot());
    unawaited(_refreshStats());
    unawaited(BackgroundService.refreshNow());
  }

  // ---- Alerts ------------------------------------------------------------

  Future<void> addAlert(PriceAlert alert) async {
    _alerts = [..._alerts, alert];
    await _persistAlerts();
  }

  Future<void> removeAlert(String id) async {
    _alerts = _alerts.where((a) => a.id != id).toList();
    await _persistAlerts();
  }

  Future<void> toggleAlert(String id, bool enabled) async {
    for (final a in _alerts) {
      if (a.id == id) {
        a.enabled = enabled;
        if (!enabled) a.triggered = false;
      }
    }
    await _persistAlerts();
  }

  List<PriceAlert> alertsForSymbol(String symbol) =>
      _alerts.where((a) => a.symbol == symbol.toLowerCase()).toList();

  Future<void> _persistAlerts() async {
    await _storage.saveAlerts(_alerts);
    notifyListeners();
    unawaited(BackgroundService.refreshNow());
    unawaited(_syncBackend());
  }

  // ---- Portfolio ---------------------------------------------------------

  /// Add or update a holding (set amount for a symbol). Amount <= 0 removes it.
  Future<void> setHolding(String symbol, double amount) async {
    final sym = symbol.toLowerCase();
    final list = _portfolio.holdings.where((h) => h.symbol != sym).toList();
    if (amount > 0) list.add(Holding(symbol: sym, amount: amount));
    _portfolio = _portfolio.copyWith(holdings: list);
    await _persistPortfolio();
  }

  Future<void> removeHolding(String symbol) => setHolding(symbol, 0);

  Future<void> _persistPortfolio() async {
    await _storage.savePortfolio(_portfolio);
    notifyListeners();
    // New holdings/denoms may need prices; refresh subscriptions + snapshot.
    _startStreaming();
    unawaited(_primeSnapshot());
    unawaited(BackgroundService.refreshNow());
    unawaited(_syncBackend());
  }

  // ---- Portfolio alerts --------------------------------------------------

  Future<void> addPortfolioAlert(PortfolioAlert alert) async {
    _portfolioAlerts = [..._portfolioAlerts, alert];
    await _persistPortfolioAlerts();
  }

  Future<void> removePortfolioAlert(String id) async {
    _portfolioAlerts =
        _portfolioAlerts.where((a) => a.id != id).toList();
    await _persistPortfolioAlerts();
  }

  Future<void> togglePortfolioAlert(String id, bool enabled) async {
    for (final a in _portfolioAlerts) {
      if (a.id == id) {
        a.enabled = enabled;
        if (!enabled) a.triggered = false;
      }
    }
    await _persistPortfolioAlerts();
  }

  Future<void> _persistPortfolioAlerts() async {
    await _storage.savePortfolioAlerts(_portfolioAlerts);
    notifyListeners();
    _startStreaming();
    unawaited(_primeSnapshot());
    unawaited(BackgroundService.refreshNow());
    unawaited(_syncBackend());
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    _bybitTickSub?.cancel();
    _statsTimer?.cancel();
    _binance.dispose();
    _bybit.dispose();
    super.dispose();
  }
}
