import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_prices/models/coin.dart';
import 'package:crypto_prices/models/coin_stats.dart';
import 'package:crypto_prices/models/price_alert.dart';
import 'package:crypto_prices/services/bybit_service.dart';
import 'package:crypto_prices/services/market_history_service.dart';
import 'package:crypto_prices/services/storage_service.dart';

/// Daily closes reaching exactly [period] days back: [start] that long ago,
/// [last] today, and noise in between that must not be mistaken for a
/// baseline. Length is period + 1, since both endpoints are closes.
List<double> _closes({
  required int period,
  required double start,
  required double last,
}) =>
    [start, ...List.filled(period - 1, 999.0), last];

void main() {
  test('Coin builds correct Binance symbol', () {
    const coin = Coin(symbol: 'btc', name: 'Bitcoin');
    expect(coin.binanceSymbol, 'btcusdt');
    expect(coin.ticker, 'BTC');
  });

  test('Bybit subscribes only to Bybit-listed coins', () {
    // Bybit rejects the whole subscribe frame if any topic names a symbol it
    // doesn't list, which would silently stop HYPE from streaming. Non-Bybit
    // coins must never reach the subscription.
    const coins = [
      Coin(symbol: 'btc', name: 'Bitcoin'),
      Coin(symbol: 'hype', name: 'Hyperliquid', exchange: Exchange.bybit),
      Coin(symbol: 'eth', name: 'Ethereum'),
      Coin(symbol: 'kas', name: 'Kaspa', exchange: Exchange.bybit),
    ];
    expect(BybitService.symbolsFor(coins), ['HYPEUSDT', 'KASUSDT']);
  });

  test('HYPE is routed to Bybit in the catalog', () {
    final hype = coinCatalog.firstWhere((c) => c.symbol == 'hype');
    expect(hype.exchange, Exchange.bybit);
    expect(hype.bybitSymbol, 'HYPEUSDT');
  });

  test('PriceAlert above is met at or over target', () {
    final alert = PriceAlert(
      id: '1',
      symbol: 'btc',
      targetPrice: 100000,
      direction: AlertDirection.above,
    );
    expect(alert.isMet(99999), isFalse);
    expect(alert.isMet(100000), isTrue);
    expect(alert.isMet(100001), isTrue);
  });

  test('PriceAlert below is met at or under target', () {
    final alert = PriceAlert(
      id: '2',
      symbol: 'eth',
      targetPrice: 3000,
      direction: AlertDirection.below,
    );
    expect(alert.isMet(3001), isFalse);
    expect(alert.isMet(3000), isTrue);
    expect(alert.isMet(2999), isTrue);
  });

  test('period changes measure each period from its own baseline', () {
    // 91 daily closes: the last is today, so the 90d baseline is the first.
    // Values in between are noise that must not be picked up as a baseline.
    final stats =
        periodChanges('btc', _closes(period: 90, start: 100, last: 150));
    expect(stats.change90d, closeTo(50, 1e-9));

    // Each period indexes back from the end independently.
    final week = periodChanges('btc', _closes(period: 7, start: 200, last: 100));
    expect(week.change7d, closeTo(-50, 1e-9));
    expect(week.change24h, closeTo((100 - 999) / 999 * 100, 1e-9));
  });

  test('period changes are null for periods the history does not reach', () {
    // A coin listed 30 days ago has 7d and 30d but no honest 90d figure.
    final stats =
        periodChanges('new', _closes(period: 30, start: 10, last: 20));
    expect(stats.change30d, closeTo(100, 1e-9));
    expect(stats.change90d, isNull);

    final empty = periodChanges('none', const []);
    expect(empty.change24h, isNull);
    expect(empty.change90d, isNull);
  });

  test('CoinStats.copyWith merges rather than replaces', () {
    // Changes and logos arrive from different sources, so neither may wipe the
    // other when merged in.
    const withLogo = CoinStats(symbol: 'btc', imageUrl: 'https://x/btc.png');
    final merged = withLogo.copyWith(change90d: 42.0);

    expect(merged.imageUrl, 'https://x/btc.png');
    expect(merged.copyWith(change7d: 1.5).change90d, 42.0);
    expect(CoinStats.fromJson(merged.toJson()).imageUrl, 'https://x/btc.png');
  });

  test('PriceAlert round-trips through JSON', () {
    final alert = PriceAlert(
      id: '3',
      symbol: 'sol',
      targetPrice: 250.5,
      direction: AlertDirection.above,
      enabled: false,
      triggered: true,
    );
    final restored = PriceAlert.fromJson(alert.toJson());
    expect(restored.symbol, 'sol');
    expect(restored.targetPrice, 250.5);
    expect(restored.direction, AlertDirection.above);
    expect(restored.enabled, isFalse);
    expect(restored.triggered, isTrue);
  });
}
