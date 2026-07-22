import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/coin.dart';

/// Streams live prices from Bybit's public spot WebSocket.
///
/// Used for coins that aren't listed on Binance spot (e.g. Hyperliquid / HYPE).
/// Subscribes to `tickers.<SYMBOL>` topics over a single socket:
///   wss://stream.bybit.com/v5/public/spot
///
/// Spot ticker pushes are full snapshots (not deltas), so each message can be
/// consumed directly. Auto-reconnects with exponential backoff.
class BybitService {
  BybitService();

  static const String _wsUrl = 'wss://stream.bybit.com/v5/public/spot';
  static const String _restBase = 'https://api.bybit.com';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  List<String> _symbols = const []; // e.g. ["HYPEUSDT"]
  bool _disposed = false;
  int _backoffMs = 1000;
  Timer? _reconnectTimer;

  final StreamController<PriceTick> _controller =
      StreamController<PriceTick>.broadcast();

  Stream<PriceTick> get ticks => _controller.stream;

  /// Subscribe to the given Bybit-sourced coins. Reconnects only when the
  /// symbol set actually changes.
  void subscribe(List<Coin> coins) {
    final next = coins.map((c) => c.bybitSymbol).toList()..sort();
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

    try {
      final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel = channel;
      _sub = channel.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      // Send the subscribe frame once the socket is ready.
      final args = _symbols.map((s) => 'tickers.$s').toList();
      channel.sink.add(jsonEncode({'op': 'subscribe', 'args': args}));
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
    // A real message means the connection is healthy: reset backoff.
    _backoffMs = 1000;
    try {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      final topic = decoded['topic'] as String?;
      if (topic == null || !topic.startsWith('tickers.')) return;

      // Spot ticker `data` is a single object (snapshot).
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return;

      final tick = _tickFromData(data);
      if (tick != null) _controller.add(tick);
    } catch (_) {
      // Ignore malformed / non-ticker frames (subscribe acks, pings, etc.).
    }
  }

  /// Parse a Bybit spot ticker object into a [PriceTick].
  ///
  /// Bybit's `price24hPcnt` is a *fraction* (e.g. "-0.0147"), so it is scaled
  /// to a percentage to match [PriceTick.changePercent]'s convention.
  static PriceTick? _tickFromData(Map<String, dynamic> data) {
    final symbol = data['symbol'] as String?; // e.g. "HYPEUSDT"
    final price = double.tryParse(data['lastPrice'] as String? ?? '');
    if (symbol == null || price == null) return null;

    final base = symbol.replaceFirst(RegExp(r'USDT$'), '').toLowerCase();
    final pct = double.tryParse(data['price24hPcnt'] as String? ?? '');

    return PriceTick(
      symbol: base,
      price: price,
      changePercent: pct != null ? pct * 100 : 0,
    );
  }

  /// One-shot REST snapshot for the given Bybit coins.
  static Future<List<PriceTick>> fetchSnapshot(List<Coin> coins) async {
    if (coins.isEmpty) return const [];
    final out = <PriceTick>[];

    // Bybit's tickers endpoint returns all spot symbols; fetch once and filter.
    final wanted = coins.map((c) => c.bybitSymbol).toSet();
    final uri = Uri.parse('$_restBase/v5/market/tickers?category=spot');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Bybit snapshot failed: ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['result']?['list'] as List<dynamic>?) ?? const [];
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      if (!wanted.contains(m['symbol'])) continue;
      final tick = _tickFromData(m);
      if (tick != null) out.add(tick);
    }
    return out;
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
