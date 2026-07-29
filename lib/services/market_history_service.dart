import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/coin.dart';
import '../models/coin_stats.dart';

/// Multi-period price changes and chart history, taken straight from the
/// exchange that already supplies the coin's live price (Binance, or Bybit for
/// the coins Binance doesn't list).
///
/// One candle request per coin yields every period the UI shows — 24h, 7d, 30d
/// and 90d — plus the series behind the detail chart. Binance allows 6000
/// request-weight per minute and a candle request costs 2, so there is no
/// practical rate limit to design around: no API key, no shared free-tier
/// budget, and no missing periods.
class MarketHistoryService {
  static const String _binanceBase = 'https://api.binance.com';
  static const String _bybitBase = 'https://api.bybit.com';

  /// Daily candles behind the period changes: 90 days of history plus today's
  /// in-progress candle, whose close is the current price.
  static const int _statsDays = 91;

  /// Period changes (24h/7d/30d/90d) for one coin, from a single request.
  static Future<CoinStats> fetchStats(Coin coin) async {
    final series = await fetchSeries(coin, days: _statsDays);
    return periodChanges(coin.symbol, [for (final p in series) p.price]);
  }

  /// Price history covering the last [days], oldest point first.
  static Future<List<PricePoint>> fetchSeries(
    Coin coin, {
    required int days,
  }) {
    final (candle, limit) = _resolution(days);
    return coin.exchange == Exchange.bybit
        ? _bybitCandles(coin, candle, limit)
        : _binanceCandles(coin, candle, limit);
  }

  /// Candle size per range: enough points for a smooth line without pulling
  /// thousands of them.
  static (_Candle, int) _resolution(int days) => switch (days) {
        <= 1 => (_Candle.m5, 288),
        <= 7 => (_Candle.h1, 168),
        <= 30 => (_Candle.h4, 180),
        _ => (_Candle.d1, days),
      };

  static Future<List<PricePoint>> _binanceCandles(
    Coin coin,
    _Candle candle,
    int limit,
  ) async {
    final uri = Uri.parse('$_binanceBase/api/v3/klines'
        '?symbol=${coin.binanceSymbol.toUpperCase()}'
        '&interval=${candle.binance}'
        '&limit=$limit');

    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Binance klines failed: ${res.statusCode}');
    }

    // Rows are [openTime, open, high, low, close, ...], oldest first.
    final list = jsonDecode(res.body) as List<dynamic>;
    final out = <PricePoint>[];
    for (final e in list) {
      final row = e as List<dynamic>;
      final point = _point(row[0], row[4]);
      if (point != null) out.add(point);
    }
    return out;
  }

  static Future<List<PricePoint>> _bybitCandles(
    Coin coin,
    _Candle candle,
    int limit,
  ) async {
    final uri = Uri.parse('$_bybitBase/v5/market/kline'
        '?category=spot'
        '&symbol=${coin.bybitSymbol}'
        '&interval=${candle.bybit}'
        '&limit=$limit');

    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Bybit kline failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['result']?['list'] as List<dynamic>?) ?? const [];
    final out = <PricePoint>[];
    // Bybit returns newest first; everything downstream expects oldest first.
    for (final e in list.reversed) {
      final row = e as List<dynamic>;
      final point = _point(row[0], row[4]);
      if (point != null) out.add(point);
    }
    return out;
  }

  /// One candle as a point at its open time with its close price. Binance
  /// sends the timestamp as a number and Bybit as a string, so both are
  /// parsed loosely.
  static PricePoint? _point(dynamic time, dynamic close) {
    final ms = time is num ? time.toInt() : int.tryParse('$time');
    final price = close is num ? close.toDouble() : double.tryParse('$close');
    if (ms == null || price == null) return null;
    return PricePoint(
      time: DateTime.fromMillisecondsSinceEpoch(ms),
      price: price,
    );
  }
}

/// Candle sizes, with each exchange's code for them.
enum _Candle {
  m5('5m', '5'),
  h1('1h', '60'),
  h4('4h', '240'),
  d1('1d', 'D');

  const _Candle(this.binance, this.bybit);
  final String binance;
  final String bybit;
}

/// Changes over 1/7/30/90 days from [dailyCloses], oldest first and ending
/// with the current price.
///
/// A period is null when the series doesn't reach that far back — a coin
/// listed three weeks ago has no honest 90d figure.
CoinStats periodChanges(String symbol, List<double> dailyCloses) {
  double? over(int days) {
    if (dailyCloses.length <= days) return null;
    final then = dailyCloses[dailyCloses.length - 1 - days];
    if (then <= 0) return null;
    return (dailyCloses.last - then) / then * 100;
  }

  return CoinStats(
    symbol: symbol,
    change24h: over(1),
    change7d: over(7),
    change30d: over(30),
    change90d: over(90),
  );
}

/// A single [time, price] sample in a historical price series.
class PricePoint {
  const PricePoint({required this.time, required this.price});
  final DateTime time;
  final double price;
}
