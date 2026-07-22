/// Extended market stats for a coin, sourced from CoinGecko.
///
/// Provides the logo URL and multi-period change percentages that the
/// exchange price feeds (Binance/Bybit) don't supply. Refreshed by polling
/// (multi-day changes barely move minute to minute).
class CoinStats {
  const CoinStats({
    required this.symbol,
    this.imageUrl,
    this.change24h,
    this.change7d,
    this.change30d,
  });

  /// Base asset symbol, lowercase (matches [Coin.symbol]).
  final String symbol;

  /// Logo image URL, or null if unavailable.
  final String? imageUrl;

  /// 24h / 7d / 30d change percentages (e.g. -7.9 for -7.9%). Null if missing.
  final double? change24h;
  final double? change7d;
  final double? change30d;

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'imageUrl': imageUrl,
        'change24h': change24h,
        'change7d': change7d,
        'change30d': change30d,
      };

  factory CoinStats.fromJson(Map<String, dynamic> json) => CoinStats(
        symbol: json['symbol'] as String,
        imageUrl: json['imageUrl'] as String?,
        change24h: (json['change24h'] as num?)?.toDouble(),
        change7d: (json['change7d'] as num?)?.toDouble(),
        change30d: (json['change30d'] as num?)?.toDouble(),
      );
}
