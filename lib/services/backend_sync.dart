import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/portfolio.dart';
import '../models/portfolio_alert.dart';
import '../models/price_alert.dart';

/// Uploads the user's alert definitions to the push backend so it can evaluate
/// them 24/7 and push instant FCM notifications.
///
/// No-op when push isn't configured or the FCM token isn't available yet.
class BackendSync {
  BackendSync._();
  static final BackendSync instance = BackendSync._();

  String? _fcmToken;

  set fcmToken(String? t) => _fcmToken = t;

  /// Push the current alert bundle for this device. Debounced by the caller.
  Future<void> sync({
    required List<PriceAlert> priceAlerts,
    required Portfolio portfolio,
    required List<PortfolioAlert> portfolioAlerts,
  }) async {
    if (!AppConfig.pushEnabled) return;
    final token = _fcmToken;
    if (token == null) return;

    final body = {
      'token': token,
      'bundle': {
        'priceAlerts': priceAlerts
            .where((a) => a.enabled)
            .map((a) => {
                  'id': a.id,
                  'symbol': a.symbol,
                  'targetPrice': a.targetPrice,
                  'direction': a.direction.name,
                  'enabled': a.enabled,
                })
            .toList(),
        'holdings': portfolio.holdings
            .map((h) => {'symbol': h.symbol, 'amount': h.amount})
            .toList(),
        'portfolioAlerts': portfolioAlerts
            .where((a) => a.enabled)
            .map((a) => {
                  'id': a.id,
                  'denom': a.denom.name,
                  'denomSymbol': a.denomSymbol,
                  'targetAmount': a.targetAmount,
                  'direction': a.direction.name,
                  'enabled': a.enabled,
                })
            .toList(),
      },
    };

    try {
      final res = await http
          .post(
            Uri.parse('${AppConfig.pushBackendUrl}/sync'),
            headers: {
              'content-type': 'application/json',
              if (AppConfig.pushApiKey.isNotEmpty)
                'x-api-key': AppConfig.pushApiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('[sync] backend returned ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[sync] failed: $e');
    }
  }
}
