/// Direction a price must cross to trigger an alert.
enum AlertDirection {
  /// Fire when price rises to or above [PriceAlert.targetPrice].
  above,

  /// Fire when price falls to or below [PriceAlert.targetPrice].
  below,
}

/// A user-configured price alert for a single coin.
class PriceAlert {
  PriceAlert({
    required this.id,
    required this.symbol,
    required this.targetPrice,
    required this.direction,
    this.enabled = true,
    this.triggered = false,
  });

  /// Unique id (millisecond timestamp string at creation).
  final String id;

  /// Base asset symbol, lowercase (matches [Coin.symbol]).
  final String symbol;

  /// Price threshold in USDT.
  final double targetPrice;

  final AlertDirection direction;

  /// When false the alert is ignored during checks.
  bool enabled;

  /// Set true once fired so we don't spam the user repeatedly.
  /// Reset when the price moves back to the other side of the threshold.
  bool triggered;

  /// Whether [price] satisfies this alert's crossing condition.
  bool isMet(double price) => direction == AlertDirection.above
      ? price >= targetPrice
      : price <= targetPrice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'targetPrice': targetPrice,
        'direction': direction.name,
        'enabled': enabled,
        'triggered': triggered,
      };

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        targetPrice: (json['targetPrice'] as num).toDouble(),
        direction: AlertDirection.values
            .firstWhere((d) => d.name == json['direction']),
        enabled: json['enabled'] as bool? ?? true,
        triggered: json['triggered'] as bool? ?? false,
      );
}
