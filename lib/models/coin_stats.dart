/// Extended market stats for a coin: the logo and the multi-period change
/// percentages that the live price feed doesn't carry.
///
/// Changes come from exchange candles (see MarketHistoryService) and the logo
/// from CoinLogoService, so an instance is usually assembled from two sources —
/// hence [copyWith] merging rather than replacing.
class CoinStats {
  const CoinStats({
    required this.symbol,
    this.imageUrl,
    this.change24h,
    this.change7d,
    this.change30d,
    this.change90d,
  });

  /// Base asset symbol, lowercase (matches [Coin.symbol]).
  final String symbol;

  /// Logo image URL, or null if unavailable.
  final String? imageUrl;

  /// 24h / 7d / 30d / 90d change percentages (e.g. -7.9 for -7.9%). Null when
  /// the coin's price history doesn't reach back that far.
  final double? change24h;
  final double? change7d;
  final double? change30d;
  final double? change90d;

  /// Merge in new values. A null argument keeps the current value, so freshly
  /// fetched changes don't drop the logo (and vice versa).
  CoinStats copyWith({
    String? imageUrl,
    double? change24h,
    double? change7d,
    double? change30d,
    double? change90d,
  }) =>
      CoinStats(
        symbol: symbol,
        imageUrl: imageUrl ?? this.imageUrl,
        change24h: change24h ?? this.change24h,
        change7d: change7d ?? this.change7d,
        change30d: change30d ?? this.change30d,
        change90d: change90d ?? this.change90d,
      );

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'imageUrl': imageUrl,
        'change24h': change24h,
        'change7d': change7d,
        'change30d': change30d,
        'change90d': change90d,
      };

  factory CoinStats.fromJson(Map<String, dynamic> json) => CoinStats(
        symbol: json['symbol'] as String,
        imageUrl: json['imageUrl'] as String?,
        change24h: (json['change24h'] as num?)?.toDouble(),
        change7d: (json['change7d'] as num?)?.toDouble(),
        change30d: (json['change30d'] as num?)?.toDouble(),
        change90d: (json['change90d'] as num?)?.toDouble(),
      );
}
