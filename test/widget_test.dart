import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_prices/models/coin.dart';
import 'package:crypto_prices/models/price_alert.dart';

void main() {
  test('Coin builds correct Binance symbol', () {
    const coin = Coin(symbol: 'btc', name: 'Bitcoin');
    expect(coin.binanceSymbol, 'btcusdt');
    expect(coin.ticker, 'BTC');
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
