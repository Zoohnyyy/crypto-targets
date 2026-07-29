import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resolves coin logo URLs from Coinpaprika — free, no API key, and it covers
/// recent listings that the static icon repos on GitHub never picked up.
///
/// Exchanges don't serve artwork, so this is the one thing the price feeds
/// can't provide. A logo never changes, so each coin costs exactly one small
/// search request ever: callers cache the resulting URL (see
/// StorageService.cacheStats) and only ask again for coins they have none for.
class CoinLogoService {
  static const String _api = 'https://api.coinpaprika.com/v1';
  static const String _cdn = 'https://static.coinpaprika.com/coin';

  /// Logo URL for a base symbol (e.g. "btc"), or null if nothing matches.
  ///
  /// Symbols aren't unique — plenty of long-dead tokens squat on a popular
  /// ticker — so only exact symbol matches are considered and the best-ranked
  /// one wins. Unranked entries are ignored entirely.
  static Future<String?> fetchLogoUrl(String symbol) async {
    final query = Uri.encodeQueryComponent(symbol);
    // The trailing slash matters: without it the API answers 301.
    final uri = Uri.parse('$_api/search/?q=$query&c=currencies&limit=10');

    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Coinpaprika search failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final currencies = (body['currencies'] as List<dynamic>?) ?? const [];

    String? bestId;
    var bestRank = 1 << 31;
    for (final e in currencies) {
      final m = e as Map<String, dynamic>;
      final sym = (m['symbol'] as String?)?.toLowerCase();
      final id = m['id'] as String?;
      final rank = (m['rank'] as num?)?.toInt() ?? 0;
      if (id == null || sym != symbol.toLowerCase() || rank <= 0) continue;
      if (rank < bestRank) {
        bestRank = rank;
        bestId = id;
      }
    }

    return bestId == null ? null : '$_cdn/$bestId/logo.png';
  }
}
