import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../models/portfolio.dart';
import '../models/portfolio_alert.dart';
import '../models/price_alert.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';
import '../services/portfolio_math.dart';
import '../services/storage_service.dart';
import 'coin_logo.dart';
import 'coin_picker.dart';
import 'format.dart';
import 'theme/app_theme.dart';
import 'theme/glass.dart';

/// Manage the portfolio (holdings), see its live value, and set alerts on the
/// total value denominated in USD or another token.
class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final holdings = state.portfolio.holdings;
    final alerts = state.portfolioAlerts;

    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editHolding(context, state),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add holding',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _ValueCard(usd: state.portfolioUsdValue),
          const SizedBox(height: 20),
          _sectionTitle(context, 'Holdings'),
          const SizedBox(height: 8),
          if (holdings.isEmpty)
            _hint(context,
                'No holdings yet. Add the tokens you own and how many.')
          else
            ...holdings.map((h) => _HoldingRow(
                  holding: h,
                  state: state,
                  onTap: () => _editHolding(context, state, existing: h),
                )),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _sectionTitle(context, 'Portfolio alerts')),
              TextButton.icon(
                onPressed: holdings.isEmpty
                    ? null
                    : () => _addAlert(context, state),
                icon: const Icon(Icons.add_alert, size: 18),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (alerts.isEmpty)
            _hint(context,
                'Get notified when your whole portfolio reaches a target '
                'value — in USD or in units of another token.')
          else
            ...alerts.map((a) => _AlertRow(alert: a, state: state)),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String t) => Text(
        t,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      );

  Widget _hint(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          t,
          style: TextStyle(
            color: AppColors.muted(Theme.of(context).brightness),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      );

  void _editHolding(BuildContext context, AppState state, {Holding? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(Theme.of(context).brightness),
      builder: (_) => _HoldingSheet(state: state, existing: existing),
    );
  }

  void _addAlert(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(Theme.of(context).brightness),
      builder: (_) => _AlertSheet(state: state),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.usd});
  final double usd;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL VALUE',
              style: TextStyle(
                letterSpacing: 1,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted(Theme.of(context).brightness),
              )),
          const SizedBox(height: 8),
          Text(
            // Portfolio total always uses 2-decimal USD (avoids $0.00000000).
            formatDenomValue(usd, AlertDenom.usd, null),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow(
      {required this.holding, required this.state, required this.onTap});
  final Holding holding;
  final AppState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tick = state.priceFor(holding.symbol);
    final value = tick != null ? holding.amount * tick.price : null;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          CoinLogo(
              ticker: holding.symbol.toUpperCase(),
              imageUrl: state.statsFor(holding.symbol)?.imageUrl,
              size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_trimAmount(holding.amount)} '
                    '${holding.symbol.toUpperCase()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  tick != null ? '@ ${formatUsd(tick.price)}' : 'No price',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted(Theme.of(context).brightness),
                  ),
                ),
              ],
            ),
          ),
          Text(
            value != null ? formatUsd(value) : '—',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.state});
  final PortfolioAlert alert;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final up = alert.direction == AlertDirection.above;
    final color = up ? AppColors.green : AppColors.red;
    final now = state.portfolioAlertValue(alert);
    final target =
        formatDenomValue(alert.targetAmount, alert.denom, alert.denomSymbol);

    return Dismissible(
      key: ValueKey(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: AppColors.red),
      ),
      onDismissed: (_) => state.removePortfolioAlert(alert.id),
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(up ? Icons.trending_up : Icons.trending_down,
                  color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Portfolio ${up ? "≥" : "≤"} $target',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    now != null
                        ? 'Now ${formatDenomValue(now, alert.denom, alert.denomSymbol)}'
                        : 'Waiting for price…',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted(Theme.of(context).brightness),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: alert.enabled,
              onChanged: (v) => state.togglePortfolioAlert(alert.id, v),
            ),
          ],
        ),
      ),
    );
  }
}

String _trimAmount(double v) {
  var s = v.toStringAsFixed(8);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

// ---- Holding add/edit sheet ------------------------------------------------

class _HoldingSheet extends StatefulWidget {
  const _HoldingSheet({required this.state, this.existing});
  final AppState state;
  final Holding? existing;

  @override
  State<_HoldingSheet> createState() => _HoldingSheetState();
}

class _HoldingSheetState extends State<_HoldingSheet> {
  late Coin _coin;
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _coin = widget.existing != null
        ? _coinFor(widget.existing!.symbol)
        : coinCatalog.first;
    if (widget.existing != null) {
      _amountController.text = _trimAmount(widget.existing!.amount);
    }
  }

  Coin _coinFor(String symbol) {
    for (final c in coinCatalog) {
      if (c.symbol == symbol.toLowerCase()) return c;
    }
    return Coin(symbol: symbol, name: symbol.toUpperCase());
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(editing ? 'Edit holding' : 'Add holding',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          CoinPickerField(
            label: 'Token',
            selected: _coin,
            enabled: !editing,
            onChanged: (c) => setState(() => _coin = c),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: _coin.ticker,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              if (editing)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.state.removeHolding(_coin.symbol);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                ),
              if (editing) const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    await widget.state.setHolding(_coin.symbol, amount);
    if (mounted) Navigator.pop(context);
  }
}

// ---- Portfolio alert sheet -------------------------------------------------

class _AlertSheet extends StatefulWidget {
  const _AlertSheet({required this.state});
  final AppState state;

  @override
  State<_AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends State<_AlertSheet> {
  AlertDenom _denom = AlertDenom.usd;
  AlertDirection _direction = AlertDirection.above;
  Coin _denomCoin = const Coin(symbol: 'eth', name: 'Ethereum');
  final _targetController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New portfolio alert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          SegmentedButton<AlertDenom>(
            segments: const [
              ButtonSegment(value: AlertDenom.usd, label: Text('USD')),
              ButtonSegment(value: AlertDenom.token, label: Text('Token')),
            ],
            selected: {_denom},
            onSelectionChanged: (s) => setState(() => _denom = s.first),
          ),
          const SizedBox(height: 16),
          SegmentedButton<AlertDirection>(
            segments: const [
              ButtonSegment(
                  value: AlertDirection.above,
                  label: Text('Rises to ≥'),
                  icon: Icon(Icons.trending_up)),
              ButtonSegment(
                  value: AlertDirection.below,
                  label: Text('Falls to ≤'),
                  icon: Icon(Icons.trending_down)),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
          const SizedBox(height: 16),
          if (_denom == AlertDenom.token) ...[
            CoinPickerField(
              label: 'Denominated in',
              selected: _denomCoin,
              onChanged: (c) => setState(() => _denomCoin = c),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _targetController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Target',
              prefixText: _denom == AlertDenom.usd ? '\$ ' : null,
              suffixText:
                  _denom == AlertDenom.token ? _denomCoin.ticker : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          GradientButton(
            icon: Icons.check,
            onPressed: _save,
            child: const Text('Create alert'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final target = double.tryParse(_targetController.text.trim());
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid target')),
      );
      return;
    }
    await NotificationService.instance.requestPermission();

    final alert = PortfolioAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      denom: _denom,
      denomSymbol: _denom == AlertDenom.token ? _denomCoin.symbol : null,
      targetAmount: target,
      direction: _direction,
    );
    await widget.state.addPortfolioAlert(alert);
    if (mounted) Navigator.pop(context);
  }
}
