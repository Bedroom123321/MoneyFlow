import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'statistics_screen.dart';
import 'wallet_list_screen.dart';
import 'categories_screen.dart';
import 'add_transaction_screen.dart';
import '../database/database_helper.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _refreshKey = 0;

  List<Widget> get _screens => [
    HomeScreen(key: ValueKey('home_$_refreshKey')),
    StatisticsScreen(key: ValueKey('stats_$_refreshKey')),
    const WalletListScreen(),
    const CategoriesScreen(),
  ];

  Future<void> _onFabPressed() async {
    final wallet = await DatabaseHelper.instance.getActiveWallet();
    if (!mounted || wallet == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionScreen(wallet: wallet)),
    );
    if (result == true) setState(() => _refreshKey++);
  }

  void _onTabTapped(int index) {
    // Если уходим с вкладки кошельков — обновляем home и статистику
    if (_currentIndex == 2 && index != 2) {
      setState(() {
        _currentIndex = index;
        _refreshKey++;
      });
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screens = _screens;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              selected: _currentIndex == 0,
              onTap: () => _onTabTapped(0),
            ),
            _NavItem(
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart,
              selected: _currentIndex == 1,
              onTap: () => _onTabTapped(1),
            ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _onFabPressed,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      color: colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet,
              selected: _currentIndex == 2,
              onTap: () => _onTabTapped(2),
            ),
            _NavItem(
              icon: Icons.category_outlined,
              selectedIcon: Icons.category,
              selected: _currentIndex == 3,
              onTap: () => _onTabTapped(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Icon(
            selected ? selectedIcon : icon,
            color: color,
            size: 26,
          ),
        ),
      ),
    );
  }
}
