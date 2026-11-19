import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/widgets/app_bottom_nav_bar.dart';
import 'package:expensetracker/core/widgets/app_floating_action_button.dart';
import 'package:expensetracker/features/analytics/screens/analytics_screen.dart';
import 'package:expensetracker/features/dashboard/screens/home_screen.dart';
import 'package:expensetracker/features/goals/screens/goals_screen.dart';
import 'package:expensetracker/features/settings/screens/settings_screen.dart';
import 'package:expensetracker/features/transactions/screens/add_transaction_screen.dart';
import 'package:expensetracker/features/transactions/screens/transactions_screen.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// Root navigation shell that houses the five bottom navigation tabs
/// and the central floating action button.
class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _openAddTransactionScreen({bool isExpense = true}) async {
    final dashboard = context.read<DashboardProvider>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider<DashboardProvider>.value(
          value: dashboard,
          child: AddTransactionScreen(initialIsExpense: isExpense),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        onSeeAllTransactions: () => _navigateToTab(1),
        onAddTransaction: () => _openAddTransactionScreen(),
        onAddTransactionForType: (isExpense) =>
            _openAddTransactionScreen(isExpense: isExpense),
      ),
      TransactionsScreen(onAddTransaction: () => _openAddTransactionScreen()),
      const AnalyticsScreen(),
      const GoalsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
      ),
      floatingActionButton:
          _currentIndex != 3 &&
              _currentIndex !=
                  4 // Hide on Goals and More
          ? AppFloatingActionButton(
              onPressed: () => _openAddTransactionScreen(),
              tooltip: 'Add Transaction',
            )
          : null,
    );
  }
}
