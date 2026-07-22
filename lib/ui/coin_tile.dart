import 'package:flutter/material.dart';

import '../models/coin.dart';
import '../models/coin_stats.dart';
import 'coin_logo.dart';
import 'format.dart';
import 'theme/app_theme.dart';
import 'theme/flash_price.dart';
import 'theme/glass.dart';

Color changeColor(double? pct) =>
    (pct ?? 0) >= 0 ? AppColors.green : AppColors.red;

/// A single watchlist entry rendered as a solid card.
///
/// Shows everything on one card: the live (flashing) price + 24h pill, and a
/// strip of 24h / 7d / 30d change percentages below.
class CoinTile extends StatelessWidget {
  const CoinTile({
    super.key,
    required this.coin,
    required this.tick,
    required this.stats,
    required this.editing,
    this.onRemove,
    this.onTap,
  });

  final Coin coin;
  final PriceTick? tick;
  final CoinStats? stats;
  final bool editing;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: editing ? null : onTap,
      child: Column(
        children: [
          Row(
            children: [
              CoinLogo(
                  ticker: coin.ticker, imageUrl: stats?.imageUrl, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coin.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coin.ticker,
                      style: TextStyle(
                        fontSize: 12.5,
                        letterSpacing: 0.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              if (editing)
                IconButton(
                  icon:
                      const Icon(Icons.remove_circle, color: AppColors.red),
                  onPressed: onRemove,
                )
              else
                FlashPrice(
                  price: tick?.price,
                  text: tick != null ? formatUsd(tick!.price) : '—',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          // Period changes strip: 24h / 7d / 30d. The 24h prefers the live
          // exchange feed so it stays real-time; 7d/30d come from CoinGecko.
          if (!editing) ...[
            const SizedBox(height: 12),
            _PeriodStrip(
              d1: tick?.changePercent ?? stats?.change24h,
              d7: stats?.change7d,
              d30: stats?.change30d,
            ),
          ],
        ],
      ),
    );
  }
}

/// A row of 24h / 7d / 30d change figures, each labelled, separated by thin
/// dividers. Sits below the price on each coin card.
class _PeriodStrip extends StatelessWidget {
  const _PeriodStrip({this.d1, this.d7, this.d30});

  final double? d1;
  final double? d7;
  final double? d30;

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      width: 1,
      height: 22,
      color: Theme.of(context).dividerColor,
    );
    return Row(
      children: [
        Expanded(child: _seg(context, '24H', d1)),
        divider,
        Expanded(child: _seg(context, '7D', d7)),
        divider,
        Expanded(child: _seg(context, '30D', d30)),
      ],
    );
  }

  Widget _seg(BuildContext context, String label, double? pct) {
    final muted = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.45);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          pct != null ? formatChange(pct) : '—',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: pct != null ? changeColor(pct) : muted,
          ),
        ),
      ],
    );
  }
}
