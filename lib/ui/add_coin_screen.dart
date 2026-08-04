import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../providers/app_state.dart';
import '../services/binance_service.dart';
import '../services/storage_service.dart';
import 'coin_logo.dart';
import 'theme/app_theme.dart';
import 'theme/glass.dart';

/// Search and add coins to the watchlist.
///
/// Shows the curated catalog first (with friendly names), and falls back to the
/// full list of Binance USDT pairs fetched from the exchange for anything else.
class AddCoinScreen extends StatefulWidget {
  const AddCoinScreen({super.key});

  @override
  State<AddCoinScreen> createState() => _AddCoinScreenState();
}

class _AddCoinScreenState extends State<AddCoinScreen> {
  String _query = '';
  List<String> _allBases = [];
  bool _loadingAll = false;

  @override
  void initState() {
    super.initState();
    _loadAllPairs();
  }

  Future<void> _loadAllPairs() async {
    setState(() => _loadingAll = true);
    try {
      _allBases = await BinanceService.fetchAvailableUsdtBases();
    } catch (_) {
      // Catalog-only fallback if the network call fails.
    } finally {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  /// Build the merged, de-duplicated, filtered result list.
  List<Coin> _results() {
    final q = _query.trim().toLowerCase();
    final seen = <String>{};
    final out = <Coin>[];

    // Catalog matches first (nicer names, ranked). Fixed-price coins are
    // skipped: the watchlist tracks price movement, and USDT against USDT is a
    // flat $1.00 with no chart behind it. It stays available as a holding.
    for (final c in coinCatalog) {
      if (fixedUsdPrice(c.symbol) != null) continue;
      if (q.isEmpty ||
          c.symbol.contains(q) ||
          c.name.toLowerCase().contains(q)) {
        if (seen.add(c.symbol)) out.add(c);
      }
    }

    // Then any other tradeable USDT bases from the exchange.
    for (final base in _allBases) {
      if (seen.contains(base)) continue;
      if (q.isEmpty || base.contains(q)) {
        out.add(Coin(symbol: base, name: nameForSymbol(base)));
        seen.add(base);
      }
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final results = _results();

    return SpaceBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Add coin',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                borderRadius: 18,
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search e.g. BTC, Solana…',
                    prefixIcon: const Icon(Icons.search),
                    border: InputBorder.none,
                    suffixIcon: _loadingAll
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No matching coins'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final coin = results[i];
                        final added = state.isWatched(coin.symbol);
                        return GlassCard(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          onTap: added
                              ? null
                              : () async {
                                  await state.addCoin(coin);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text('${coin.ticker} added'),
                                      behavior: SnackBarBehavior.floating,
                                      duration:
                                          const Duration(milliseconds: 900),
                                    ));
                                  }
                                },
                          child: Row(
                            children: [
                              CoinLogo(
                                ticker: coin.ticker,
                                imageUrl:
                                    state.statsFor(coin.symbol)?.imageUrl,
                                size: 40,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(coin.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('${coin.ticker} · USDT',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                        )),
                                  ],
                                ),
                              ),
                              Icon(
                                added
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                color: added ? AppColors.green : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
