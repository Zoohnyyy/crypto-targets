import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/coin.dart';
import '../models/coin_stats.dart';
import 'storage_service.dart';

/// Fetches logos and 24h/7d/30d change percentages from CoinGecko.
///
/// The exchange price feeds only give live price + 24h change; CoinGecko's
/// `/coins/markets` endpoint additionally provides the logo URL and the 7d/30d
/// change in a single request. This is polled (multi-day changes don't need
/// sub-second updates) and the free endpoint is rate-limited, so keep the poll
/// interval generous (see AppState).
class CoinGeckoService {
  static const String _base = 'https://api.coingecko.com/api/v3';

  /// Lazily-built map of lowercase symbol -> CoinGecko id, from `/coins/list`.
  /// Lets us resolve logos/stats for any coin the user adds from the exchange
  /// list, not just the curated catalog. First occurrence of a symbol wins.
  static Map<String, String>? _symbolToId;
  static Future<Map<String, String>>? _symbolToIdFuture;

  /// Fetch (and cache) the full symbol -> id map from CoinGecko.
  static Future<Map<String, String>> _loadSymbolMap() {
    if (_symbolToId != null) return Future.value(_symbolToId);
    return _symbolToIdFuture ??= () async {
      try {
        final uri = Uri.parse('$_base/coins/list');
        final res = await http.get(uri).timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) return <String, String>{};
        final list = jsonDecode(res.body) as List<dynamic>;
        final map = <String, String>{};
        for (final e in list) {
          final m = e as Map<String, dynamic>;
          final sym = (m['symbol'] as String?)?.toLowerCase();
          final id = m['id'] as String?;
          if (sym == null || id == null) continue;
          // Keep the first id seen for a symbol (avoids clobbering the
          // canonical coin with an obscure duplicate later in the list).
          map.putIfAbsent(sym, () => id);
        }
        _symbolToId = map;
        return map;
      } catch (_) {
        return <String, String>{};
      } finally {
        _symbolToIdFuture = null;
      }
    }();
  }

  /// Resolve a coin's CoinGecko id: explicit field, then curated catalog, then
  /// the dynamic `/coins/list` map.
  static String? _resolveId(Coin c, Map<String, String> symbolMap) {
    return c.coingeckoId ??
        coingeckoIdForSymbol(c.symbol) ??
        symbolMap[c.symbol.toLowerCase()];
  }

  /// Fetch stats (logo + 24h/7d/30d change) for every watchlist coin.
  ///
  /// Returns a map keyed by base symbol (lowercase). Ids are resolved from the
  /// curated catalog and, for anything else, CoinGecko's full coin list.
  static Future<Map<String, CoinStats>> fetchStats(List<Coin> coins) async {
    final symbolMap = await _loadSymbolMap();

    // Resolve ids, keeping a reverse map from CoinGecko id -> base symbol so we
    // can key results by our own symbol regardless of CoinGecko's symbol.
    final idToSymbol = <String, String>{};
    for (final c in coins) {
      final id = _resolveId(c, symbolMap);
      if (id != null) idToSymbol[id] = c.symbol;
    }
    if (idToSymbol.isEmpty) return {};

    final ids = idToSymbol.keys.join(',');
    final uri = Uri.parse(
      '$_base/coins/markets'
      '?vs_currency=usd'
      '&ids=$ids'
      '&price_change_percentage=24h,7d,30d'
      '&sparkline=false',
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('CoinGecko markets failed: ${res.statusCode}');
    }

    final list = jsonDecode(res.body) as List<dynamic>;
    final out = <String, CoinStats>{};
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final id = m['id'] as String?;
      final symbol = id != null ? idToSymbol[id] : null;
      if (symbol == null) continue;

      out[symbol] = CoinStats(
        symbol: symbol,
        imageUrl: m['image'] as String?,
        change24h:
            (m['price_change_percentage_24h_in_currency'] as num?)?.toDouble(),
        change7d:
            (m['price_change_percentage_7d_in_currency'] as num?)?.toDouble(),
        change30d:
            (m['price_change_percentage_30d_in_currency'] as num?)?.toDouble(),
      );
    }
    return out;
  }

  /// Fetch a historical price series for one coin over [days] (1 = daily view,
  /// 7 = weekly, 30 = monthly).
  ///
  /// Returns time-ordered points, or an empty list if the coin can't be
  /// resolved or the request fails. Used by the coin detail chart.
  static Future<List<PricePoint>> fetchMarketChart(
    Coin coin, {
    required int days,
  }) async {
    final symbolMap = await _loadSymbolMap();
    final id = _resolveId(coin, symbolMap);
    if (id == null) return const [];

    final uri = Uri.parse(
      '$_base/coins/$id/market_chart?vs_currency=usd&days=$days',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('CoinGecko market_chart failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final prices = (body['prices'] as List<dynamic>?) ?? const [];
    final points = <PricePoint>[];
    for (final e in prices) {
      final pair = e as List<dynamic>;
      final ts = (pair[0] as num).toInt();
      final price = (pair[1] as num).toDouble();
      points.add(PricePoint(
        time: DateTime.fromMillisecondsSinceEpoch(ts),
        price: price,
      ));
    }
    return points;
  }
}

/// A single [time, price] sample in a historical price series.
class PricePoint {
  const PricePoint({required this.time, required this.price});
  final DateTime time;
  final double price;
}
