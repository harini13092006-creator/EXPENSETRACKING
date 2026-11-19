import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// Shows the authenticated user's onboarding savings target and current-month progress.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final target = dashboard.savingsGoal;
    final saved = dashboard.currentMonthSummary.netSavings;
    final remaining = (target - saved).clamp(0.0, double.infinity);
    final progress = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF153328), Color(0xFF0F241C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppSpacing.roundedXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.savings_rounded,
                  color: Color(0xFF68E1A7),
                  size: 30,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  dashboard.primaryGoal.isEmpty
                      ? 'Monthly savings target'
                      : dashboard.primaryGoal,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  target > 0
                      ? '${AppConstants.currencySymbol}${saved.toStringAsFixed(2)} saved this month'
                      : 'Set a savings target in your profile to track progress.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ClipRRect(
                  borderRadius: AppSpacing.roundedPill,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    color: const Color(0xFF68E1A7),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (target > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% complete',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        remaining == 0
                            ? 'Goal reached'
                            : '${AppConstants.currencySymbol}${remaining.toStringAsFixed(2)} to go',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Monthly net savings'),
              subtitle: const Text(
                'Income minus expenses for the selected month',
              ),
              trailing: Text(
                '${AppConstants.currencySymbol}${saved.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
