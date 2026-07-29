import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'portfolio_screen.dart';

/// Root navigation: holdings and watchlist as sibling tabs.
///
/// Holdings is index 0, so the app opens on the portfolio. Both tabs live in an
/// [IndexedStack] so switching keeps each screen's scroll position, edit mode,
/// and in-flight state instead of rebuilding it.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          PortfolioScreen(),
          HomeScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Holdings',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Watchlist',
          ),
        ],
      ),
    );
  }
}
