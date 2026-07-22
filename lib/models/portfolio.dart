/// A single holding in the user's portfolio: an amount of a token.
class Holding {
  const Holding({required this.symbol, required this.amount});

  /// Base asset symbol, lowercase (matches [Coin.symbol]), e.g. "btc".
  final String symbol;

  /// How many units of the token are held (e.g. 0.5 BTC).
  final double amount;

  Holding copyWith({double? amount}) =>
      Holding(symbol: symbol, amount: amount ?? this.amount);

  Map<String, dynamic> toJson() => {'symbol': symbol, 'amount': amount};

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
        symbol: json['symbol'] as String,
        amount: (json['amount'] as num).toDouble(),
      );
}

/// The user's single portfolio — a list of holdings.
class Portfolio {
  const Portfolio({this.holdings = const []});

  final List<Holding> holdings;

  Portfolio copyWith({List<Holding>? holdings}) =>
      Portfolio(holdings: holdings ?? this.holdings);

  /// All token symbols referenced by the portfolio (lowercase).
  List<String> get symbols => holdings.map((h) => h.symbol).toList();

  Map<String, dynamic> toJson() =>
      {'holdings': holdings.map((h) => h.toJson()).toList()};

  factory Portfolio.fromJson(Map<String, dynamic> json) => Portfolio(
        holdings: ((json['holdings'] as List<dynamic>?) ?? const [])
            .map((e) => Holding.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
