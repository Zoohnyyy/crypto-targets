import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/coin.dart';

/// Streams live prices from Binance's public market data WebSocket.
///
/// Uses the *combined* ticker stream so any number of symbols is served over a
/// single socket. The stream endpoint looks like:
///   wss://stream.binance.com:9443/stream?streams=btcusdt@ticker/ethusdt@ticker
///
/// Automatically reconnects with exponential backoff on drop.
class BinanceService {
  BinanceService();

  static const String _wsBase = 'wss://stream.binance.com:9443/stream';
  static const String _restBase = 'https://api.binance.com';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  List<String> _symbols = const [];
  bool _disposed = false;
  int _backoffMs = 1000;
  Timer? _reconnectTimer;

  final StreamController<PriceTick> _controller =
      StreamController<PriceTick>.broadcast();

  /// Broadcast stream of live price ticks for the currently subscribed symbols.
  Stream<PriceTick> get ticks => _controller.stream;

  /// Subscribe to the given coins. Only Binance-sourced coins are used; coins
  /// on other exchanges are ignored here (handled by their own service).
  /// Safe to call repeatedly; it reconnects only when the symbol set changes.
  void subscribe(List<Coin> coins) {
    final next = coins
        .where((c) => c.exchange == Exchange.binance)
        .map((c) => c.binanceSymbol)
        .toList()
      ..sort();
    if (_listEquals(next, _symbols) && _channel != null) return;
    _symbols = next;
    _reconnect();
  }

  void _reconnect() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;

    if (_disposed || _symbols.isEmpty) return;

    final streams = _symbols.map((s) => '$s@ticker').join('/');
    final uri = Uri.parse('$_wsBase?streams=$streams');

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _symbols.isEmpty) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _backoffMs), () {
      _backoffMs = (_backoffMs * 2).clamp(1000, 30000);
      _reconnect();
    });
  }

  void _onMessage(dynamic raw) {
    // Reaching a real message means the connection is healthy: reset backoff so
    // the next disconnect retries quickly.
    _backoffMs = 1000;
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      // Combined stream wraps payloads: { "stream": "...", "data": {...} }
      final data = decoded['data'] as Map<String, dynamic>?;
      if (data == null) return;

      // Binance 24hr ticker fields: s=symbol, c=lastPrice, P=percentChange
      final streamSymbol = (data['s'] as String).toLowerCase(); // e.g. btcusdt
      final base = streamSymbol.replaceFirst(RegExp(r'usdt$'), '');
      final price = double.tryParse(data['c'] as String? ?? '');
      final change = double.tryParse(data['P'] as String? ?? '');
      if (price == null) return;

      _controller.add(PriceTick(
        symbol: base,
        price: price,
        changePercent: change ?? 0,
      ));
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  /// One-shot REST snapshot of 24hr tickers for the given symbols.
  ///
  /// Used by background tasks (widget refresh, alert checks) where holding a
  /// socket open is not appropriate, and as an initial fill before the socket
  /// warms up.
  static Future<List<PriceTick>> fetchSnapshot(List<Coin> coins) async {
    final binanceCoins =
        coins.where((c) => c.exchange == Exchange.binance).toList();
    if (binanceCoins.isEmpty) return const [];
    final symbols =
        binanceCoins.map((c) => c.binanceSymbol.toUpperCase()).toList();
    final encoded = Uri.encodeComponent(jsonEncode(symbols));
    final uri =
        Uri.parse('$_restBase/api/v3/ticker/24hr?symbols=$encoded');

    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Binance snapshot failed: ${res.statusCode}');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final streamSymbol = (m['symbol'] as String).toLowerCase();
      final base = streamSymbol.replaceFirst(RegExp(r'usdt$'), '');
      return PriceTick(
        symbol: base,
        price: double.tryParse(m['lastPrice'] as String? ?? '') ?? 0,
        changePercent:
            double.tryParse(m['priceChangePercent'] as String? ?? '') ?? 0,
      );
    }).toList();
  }

  /// Fetch the list of tradeable USDT spot symbols so the user can search and
  /// add coins. Returns lowercase base symbols (e.g. "btc").
  static Future<List<String>> fetchAvailableUsdtBases() async {
    final uri = Uri.parse('$_restBase/api/v3/exchangeInfo');
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('exchangeInfo failed: ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final symbols = data['symbols'] as List<dynamic>;
    final bases = <String>[];
    for (final s in symbols) {
      final m = s as Map<String, dynamic>;
      if (m['quoteAsset'] == 'USDT' &&
          m['status'] == 'TRADING' &&
          (m['isSpotTradingAllowed'] as bool? ?? false)) {
        bases.add((m['baseAsset'] as String).toLowerCase());
      }
    }
    bases.sort();
    return bases;
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _controller.close();
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
