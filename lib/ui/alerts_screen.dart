import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../models/price_alert.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';
import 'format.dart';
import 'theme/app_theme.dart';
import 'theme/glass.dart';

/// Manage price alerts. Optionally pre-focuses a coin (from tapping a row).
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, this.focusCoin});

  final Coin? focusCoin;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final alerts = state.alerts;

    return SpaceBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Price alerts',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddAlertSheet(context, state, focusCoin),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_alert),
          label: const Text('New alert',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: alerts.isEmpty
            ? _empty(context)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                itemCount: alerts.length,
                itemBuilder: (context, i) {
                  final alert = alerts[i];
                  final tick = state.priceFor(alert.symbol);
                  final up = alert.direction == AlertDirection.above;
                  final color = up ? AppColors.green : AppColors.red;
                  return Dismissible(
                    key: ValueKey(alert.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(Icons.delete, color: AppColors.red),
                    ),
                    onDismissed: (_) => state.removeAlert(alert.id),
                    child: GlassCard(
                      margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              up ? Icons.trending_up : Icons.trending_down,
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${alert.symbol.toUpperCase()} '
                                  '${up ? "≥" : "≤"} '
                                  '${formatUsd(alert.targetPrice)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tick != null
                                      ? 'Now ${formatUsd(tick.price)}'
                                      : 'Waiting for price…',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: alert.enabled,
                            onChanged: (v) => state.toggleAlert(alert.id, v),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_active_outlined, size: 64),
              const SizedBox(height: 16),
              Text('No alerts yet',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Get notified when a coin crosses a target price.\n'
                'Checks run in the background about every 15 minutes.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  void _showAddAlertSheet(
    BuildContext context,
    AppState state,
    Coin? preselect,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddAlertSheet(state: state, preselect: preselect),
    );
  }
}

class _AddAlertSheet extends StatefulWidget {
  const _AddAlertSheet({required this.state, this.preselect});

  final AppState state;
  final Coin? preselect;

  @override
  State<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends State<_AddAlertSheet> {
  late Coin _coin;
  AlertDirection _direction = AlertDirection.above;
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _coin = widget.preselect ??
        (widget.state.watchlist.isNotEmpty
            ? widget.state.watchlist.first
            : const Coin(symbol: 'btc', name: 'Bitcoin'));
    // Pre-fill with current price as a starting point.
    final tick = widget.state.priceFor(_coin.symbol);
    if (tick != null) _priceController.text = tick.price.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = widget.state.watchlist;

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
          Text('New price alert',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _coin.symbol,
            decoration: const InputDecoration(
              labelText: 'Coin',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final c in watchlist)
                DropdownMenuItem(
                  value: c.symbol,
                  child: Text('${c.name} (${c.ticker})'),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _coin = watchlist.firstWhere((c) => c.symbol == v);
                final tick = widget.state.priceFor(_coin.symbol);
                if (tick != null) {
                  _priceController.text = tick.price.toStringAsFixed(2);
                }
              });
            },
          ),
          const SizedBox(height: 16),
          SegmentedButton<AlertDirection>(
            segments: const [
              ButtonSegment(
                value: AlertDirection.above,
                label: Text('Rises to ≥'),
                icon: Icon(Icons.trending_up),
              ),
              ButtonSegment(
                value: AlertDirection.below,
                label: Text('Falls to ≤'),
                icon: Icon(Icons.trending_down),
              ),
            ],
            selected: {_direction},
            onSelectionChanged: (s) =>
                setState(() => _direction = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target price (USD)',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Create alert'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    // Make sure we can actually deliver the notification.
    await NotificationService.instance.requestPermission();

    final alert = PriceAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: _coin.symbol,
      targetPrice: price,
      direction: _direction,
    );
    await widget.state.addAlert(alert);
    if (mounted) Navigator.pop(context);
  }
}
