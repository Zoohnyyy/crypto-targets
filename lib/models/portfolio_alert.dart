import 'price_alert.dart';

/// How a portfolio alert's target is denominated.
enum AlertDenom {
  /// Target is a USD amount (e.g. portfolio ≥ \$50,000).
  usd,

  /// Target is expressed in units of another token (e.g. portfolio ≥ 100 ETH).
  token,
}

/// An alert on the total value of the user's portfolio.
///
/// Fires when the portfolio value — measured either in USD or in units of a
/// chosen [denomSymbol] token — crosses [targetAmount] in [direction].
class PortfolioAlert {
  PortfolioAlert({
    required this.id,
    required this.denom,
    required this.targetAmount,
    required this.direction,
    this.denomSymbol,
    this.enabled = true,
    this.triggered = false,
  });

  /// Unique id (millisecond timestamp string at creation).
  final String id;

  final AlertDenom denom;

  /// The token the target is denominated in (lowercase), when [denom] is
  /// [AlertDenom.token]. Null for USD alerts.
  final String? denomSymbol;

  /// Threshold: a USD amount, or a number of [denomSymbol] tokens.
  final double targetAmount;

  final AlertDirection direction;

  bool enabled;

  /// Set true once fired so we don't repeat until it re-arms.
  bool triggered;

  /// Whether [value] (in the same denomination) satisfies this alert.
  bool isMet(double value) => direction == AlertDirection.above
      ? value >= targetAmount
      : value <= targetAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'denom': denom.name,
        'denomSymbol': denomSymbol,
        'targetAmount': targetAmount,
        'direction': direction.name,
        'enabled': enabled,
        'triggered': triggered,
      };

  factory PortfolioAlert.fromJson(Map<String, dynamic> json) => PortfolioAlert(
        id: json['id'] as String,
        denom: AlertDenom.values
            .firstWhere((d) => d.name == json['denom'],
                orElse: () => AlertDenom.usd),
        denomSymbol: json['denomSymbol'] as String?,
        targetAmount: (json['targetAmount'] as num).toDouble(),
        direction: AlertDirection.values
            .firstWhere((d) => d.name == json['direction']),
        enabled: json['enabled'] as bool? ?? true,
        triggered: json['triggered'] as bool? ?? false,
      );
}
