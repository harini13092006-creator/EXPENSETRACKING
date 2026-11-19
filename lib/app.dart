import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/theme/app_theme.dart';
import 'package:expensetracker/features/dashboard/screens/main_nav_screen.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';
import 'package:expensetracker/providers/theme_provider.dart';

/// Root widget for ExpenseTracker with MultiProvider configuration
/// for reactive theme and dashboard state management.
class ExpenseTrackerApp extends StatelessWidget {
  final Widget? home;

  const ExpenseTrackerApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: home ?? const MainNavScreen(),
          );
        },
      ),
    );
  }
}
