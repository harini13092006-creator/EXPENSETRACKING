import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/data/models/monthly_summary_model.dart';

/// Short observations derived only from the selected and previous month data.
class SmartInsightsSection extends StatelessWidget {
  final MonthlySummaryModel summary;
  final MonthlySummaryModel previousMonth;
  final double savingsGoal;

  const SmartInsightsSection({
    super.key,
    required this.summary,
    required this.previousMonth,
    required this.savingsGoal,
  });

  @override
  Widget build(BuildContext context) {
    final insights = <(IconData, String)>[];
    final top = summary.topSpendingCategory;
    if (top != null) {
      insights.add((
        Icons.leaderboard_rounded,
        '${top.category.name} is your highest expense at ${AppConstants.currencySymbol}${top.amount.toStringAsFixed(2)}.',
      ));
    } else {
      insights.add((
        Icons.insights_rounded,
        'Add transactions to see spending insights.',
      ));
    }
    final activeCategories = summary.categorySpendings
        .where((category) => category.amount > 0)
        .toList();
    if (activeCategories.length > 1) {
      final lowest = activeCategories.reduce(
        (a, b) => a.amount < b.amount ? a : b,
      );
      insights.add((
        Icons.south_west_rounded,
        '${lowest.category.name} is your lowest-spend category at ${AppConstants.currencySymbol}${lowest.amount.toStringAsFixed(2)}.',
      ));
    }

    if (previousMonth.totalExpenses > 0) {
      final change =
          ((summary.totalExpenses - previousMonth.totalExpenses) /
              previousMonth.totalExpenses) *
          100;
      insights.add((
        Icons.compare_arrows_rounded,
        change == 0
            ? "This month-to-date spending matches last month's total."
            : "This month-to-date spending has ${change > 0 ? 'increased' : 'decreased'} by ${change.abs().toStringAsFixed(0)}% against last month's total.",
      ));
    }
    if (summary.monthlyBudget > 0 && summary.budgetUsagePercentage >= 80) {
      insights.add((
        Icons.account_balance_wallet_outlined,
        summary.isOverBudget
            ? "You are ${AppConstants.currencySymbol}${(-summary.remainingBudget).toStringAsFixed(2)} over this month's budget."
            : "You have used ${summary.budgetUsagePercentage.toStringAsFixed(0)}% of this month's budget.",
      ));
    }
    if (savingsGoal > 0) {
      final progress = (summary.netSavings / savingsGoal * 100).clamp(0, 100);
      insights.add((
        Icons.savings_outlined,
        'Savings target: ${AppConstants.currencySymbol}${savingsGoal.toStringAsFixed(2)}; ${progress.toStringAsFixed(0)}% reached this month.',
      ));
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Insights',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: .35),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < insights.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    dense: true,
                    leading: Icon(
                      insights[i].$1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      insights[i].$2,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
