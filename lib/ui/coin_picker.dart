import 'package:flutter/material.dart';

import '../models/coin.dart';
import '../services/storage_service.dart';
import 'coin_logo.dart';
import 'theme/glass.dart';

/// A tappable field showing the currently selected coin; tapping opens a
/// searchable full-screen picker over [coinCatalog]. Scales fine to 50+ coins.
class CoinPickerField extends StatelessWidget {
  const CoinPickerField({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final Coin selected;
  final ValueChanged<Coin> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: enabled,
      ),
      child: InkWell(
        onTap: enabled
            ? () async {
                final picked = await Navigator.push<Coin>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _CoinPickerScreen(initial: selected),
                  ),
                );
                if (picked != null) onChanged(picked);
              }
            : null,
        child: Row(
          children: [
            CoinLogo(ticker: selected.ticker, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${selected.name} (${selected.ticker})',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (enabled) const Icon(Icons.unfold_more, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CoinPickerScreen extends StatefulWidget {
  const _CoinPickerScreen({required this.initial});
  final Coin initial;

  @override
  State<_CoinPickerScreen> createState() => _CoinPickerScreenState();
}

class _CoinPickerScreenState extends State<_CoinPickerScreen> {
  String _query = '';

  List<Coin> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return coinCatalog;
    return coinCatalog
        .where((c) =>
            c.symbol.contains(q) || c.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a token')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              borderRadius: 14,
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tokens…',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(child: Text('No matching tokens'))
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final c = results[i];
                      final isSelected = c.symbol == widget.initial.symbol;
                      return ListTile(
                        leading: CoinLogo(ticker: c.ticker, size: 36),
                        title: Text(c.name),
                        subtitle: Text(c.ticker),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle)
                            : null,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
