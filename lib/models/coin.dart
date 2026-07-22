/// Which exchange supplies a coin's price feed.
///
/// Most coins come from Binance; a few (e.g. Hyperliquid's HYPE) aren't listed
/// on Binance and are served from Bybit instead.
enum Exchange {
  binance,
  bybit;

  static Exchange fromName(String? name) => Exchange.values.firstWhere(
        (e) => e.name == name,
        orElse: () => Exchange.binance,
      );
}

/// A cryptocurrency the user can watch.
///
/// [symbol] is the base asset symbol in lowercase without the quote asset,
/// e.g. "btc". Prices are quoted against USDT on the coin's [exchange].
class Coin {
  const Coin({
    required this.symbol,
    required this.name,
    this.exchange = Exchange.binance,
    this.coingeckoId,
  });

  /// Base asset symbol, lowercase (e.g. "btc", "eth", "sol").
  final String symbol;

  /// Human readable name (e.g. "Bitcoin").
  final String name;

  /// The exchange this coin's price feed comes from.
  final Exchange exchange;

  /// CoinGecko coin id (e.g. "bitcoin"), used to fetch the logo and the
  /// 7d/30d change stats. Null for coins added directly from the exchange
  /// list that aren't in our curated catalog.
  final String? coingeckoId;

  /// The lowercase Binance stream symbol, e.g. "btcusdt".
  String get binanceSymbol => '${symbol}usdt';

  /// The uppercase Bybit spot symbol, e.g. "HYPEUSDT".
  String get bybitSymbol => '${symbol.toUpperCase()}USDT';

  /// Upper-case display ticker, e.g. "BTC".
  String get ticker => symbol.toUpperCase();

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'exchange': exchange.name,
        if (coingeckoId != null) 'coingeckoId': coingeckoId,
      };

  factory Coin.fromJson(Map<String, dynamic> json) => Coin(
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        exchange: Exchange.fromName(json['exchange'] as String?),
        coingeckoId: json['coingeckoId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Coin && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;
}

/// A live price snapshot for a coin.
class PriceTick {
  const PriceTick({
    required this.symbol,
    required this.price,
    required this.changePercent,
  });

  /// Base asset symbol, lowercase (matches [Coin.symbol]).
  final String symbol;

  /// Latest traded price in USDT.
  final double price;

  /// 24h price change percentage (e.g. -2.34 for -2.34%).
  final double changePercent;

  PriceTick copyWith({double? price, double? changePercent}) => PriceTick(
        symbol: symbol,
        price: price ?? this.price,
        changePercent: changePercent ?? this.changePercent,
      );
}
