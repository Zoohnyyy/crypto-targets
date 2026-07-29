import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../providers/app_state.dart';
import '../services/market_history_service.dart';
import 'alerts_screen.dart';
import 'coin_logo.dart';
import 'format.dart';
import 'price_chart.dart';
import 'theme/app_theme.dart';
import 'theme/flash_price.dart';
import 'theme/glass.dart';

/// Selectable chart ranges, in days of history.
enum ChartRange {
  day('1D', 1),
  week('1W', 7),
  month('1M', 30),
  quarter('3M', 90);

  const ChartRange(this.label, this.days);
  final String label;
  final int days;
}

/// Detail page for a single coin: live header, 1D/1W/1M/3M price chart,
/// and quick access to price alerts.
class CoinDetailScreen extends StatefulWidget {
  const CoinDetailScreen({super.key, required this.coin});

  final Coin coin;

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  ChartRange _range = ChartRange.week;

  // Cache fetched series per range so switching tabs is instant after first load.
  final Map<ChartRange, List<PricePoint>> _cache = {};
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(_range);
  }

  Future<void> _load(ChartRange range) async {
    if (_cache.containsKey(range)) {
      setState(() => _range = range);
      return;
    }
    setState(() {
      _range = range;
      _loading = true;
      _error = null;
    });
    try {
      final points = await MarketHistoryService.fetchSeries(
        widget.coin,
        days: range.days,
      );
      if (!mounted) return;
      setState(() {
        _cache[range] = points;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tick = state.priceFor(widget.coin.symbol);
    final stats = state.statsFor(widget.coin.symbol);

    return SpaceBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              CoinLogo(
                ticker: widget.coin.ticker,
                imageUrl: stats?.imageUrl,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(widget.coin.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Alerts for ${widget.coin.ticker}',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlertsScreen(focusCoin: widget.coin),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _header(context, tick, stats),
            const SizedBox(height: 22),
            _rangeSelector(context),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
              child: SizedBox(height: 250, child: _chartArea()),
            ),
            const SizedBox(height: 18),
            _changeGrid(context, tick, stats),
            const SizedBox(height: 26),
            GradientButton(
              icon: Icons.add_alert,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlertsScreen(focusCoin: widget.coin),
                ),
              ),
              child: Text('Set a price alert for ${widget.coin.ticker}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, tick, stats) {
    final change = tick?.changePercent ?? stats?.change24h ?? 0;
    final up = change >= 0;
    final color = up ? AppColors.green : AppColors.red;
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CoinLogo(
            ticker: widget.coin.ticker,
            imageUrl: stats?.imageUrl,
            size: 52,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FlashPrice(
                  price: tick?.price,
                  text: tick != null ? formatUsd(tick.price) : '—',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: color, size: 20),
                    Text(
                      '${formatChange(change)}  ·  24h',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeSelector(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(5),
      borderRadius: 18,
      child: Row(
        children: [
          for (final r in ChartRange.values)
            Expanded(child: _rangeChip(context, r)),
        ],
      ),
    );
  }

  Widget _rangeChip(BuildContext context, ChartRange r) {
    final selected = _range == r;
    return GestureDetector(
      onTap: () => _load(r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          r.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _chartArea() {
    if (_loading && !_cache.containsKey(_range)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && !_cache.containsKey(_range)) {
      return _ChartError(onRetry: () => _load(_range));
    }
    final points = _cache[_range] ?? const [];
    return PriceChart(points: points);
  }

  Widget _changeGrid(BuildContext context, tick, stats) {
    final items = <(String, double?)>[
      // Live feed first, matching the header, so the two 24h figures agree.
      ('24h', tick?.changePercent ?? stats?.change24h),
      ('7d', stats?.change7d),
      ('30d', stats?.change30d),
      ('90d', stats?.change90d),
    ];
    return Row(
      children: [
        for (final (label, pct) in items)
          Expanded(
            child: GlassCard(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              borderRadius: 18,
              child: Center(
                child: Column(
                  children: [
                    Text(label.toUpperCase(),
                        style: TextStyle(
                          letterSpacing: 0.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 6),
                    // Shrink rather than overflow: four cards across leaves
                    // little room for large multi-day moves.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        pct != null ? formatChange(pct) : '—',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: pct == null
                              ? Colors.grey
                              : (pct >= 0 ? AppColors.green : AppColors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChartError extends StatelessWidget {
  const _ChartError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.show_chart, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          const Text("Couldn't load chart"),
          const SizedBox(height: 4),
          const Text(
            'Couldn’t reach the exchange. Try again in a moment.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
