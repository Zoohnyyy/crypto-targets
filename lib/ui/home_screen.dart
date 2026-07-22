import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../providers/app_state.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import 'add_coin_screen.dart';
import 'alerts_screen.dart';
import 'coin_detail_screen.dart';
import 'coin_tile.dart';
import 'portfolio_screen.dart';
import 'theme/app_theme.dart';

/// Main screen: the live, editable watchlist. Each row shows the live price,
/// 24h change, and the 7d/30d changes together.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    // Ask for notification permission on first launch (Android 13+).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.requestPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crypto Prices'),
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, theme, _) => IconButton(
              tooltip: theme.isDark
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
              icon: Icon(theme.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              onPressed: theme.toggle,
            ),
          ),
          IconButton(
            tooltip: 'Portfolio',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PortfolioScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Alerts',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
          ),
          IconButton(
            tooltip: _editing ? 'Done' : 'Edit',
            icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
            onPressed: () => setState(() => _editing = !_editing),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddCoinScreen()),
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add coin',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.watchlist.isEmpty
              ? _EmptyState()
              : _buildList(context, state),
    );
  }

  Widget _buildList(BuildContext context, AppState state) {
    final coins = state.watchlist;

    if (_editing) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 100),
        itemCount: coins.length,
        onReorderItem: state.reorderWatchlist,
        itemBuilder: (context, i) {
          final coin = coins[i];
          return CoinTile(
            key: ValueKey(coin.symbol),
            coin: coin,
            tick: state.priceFor(coin.symbol),
            stats: state.statsFor(coin.symbol),
            editing: true,
            onRemove: () => state.removeCoin(coin.symbol),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Live socket already updates; pull-to-refresh just gives feedback.
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 6, bottom: 100),
        itemCount: coins.length,
        itemBuilder: (context, i) {
          final coin = coins[i];
          return CoinTile(
            key: ValueKey(coin.symbol),
            coin: coin,
            tick: state.priceFor(coin.symbol),
            stats: state.statsFor(coin.symbol),
            editing: false,
            onTap: () => _openDetail(context, coin),
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, Coin coin) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CoinDetailScreen(coin: coin)),
    );
  }
}


class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.currency_bitcoin, size: 64),
            const SizedBox(height: 16),
            Text(
              'Your watchlist is empty',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap “Add coin” to start tracking prices.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
