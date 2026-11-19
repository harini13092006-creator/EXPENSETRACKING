import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/features/budget/widgets/set_budget_dialog.dart';
import 'package:expensetracker/features/dashboard/widgets/category_spending_section.dart';
import 'package:expensetracker/features/dashboard/widgets/dashboard_header.dart';
import 'package:expensetracker/features/dashboard/widgets/month_selector.dart';
import 'package:expensetracker/features/dashboard/widgets/monthly_summary_card.dart';
import 'package:expensetracker/features/dashboard/widgets/recent_transactions_section.dart';
import 'package:expensetracker/features/dashboard/widgets/smart_insights_section.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// The responsive Home Dashboard screen of the ExpenseTracker application.
class HomeScreen extends StatelessWidget {
  final VoidCallback onSeeAllTransactions;
  final VoidCallback onAddTransaction;
  final ValueChanged<bool>? onAddTransactionForType;

  const HomeScreen({
    super.key,
    required this.onSeeAllTransactions,
    required this.onAddTransaction,
    this.onAddTransactionForType,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboardProvider, child) {
        final summary = dashboardProvider.currentMonthSummary;
        final selectedMonth = dashboardProvider.selectedMonth;
        final previousMonthSummary = dashboardProvider.getSummaryForMonth(
          DateTime(selectedMonth.year, selectedMonth.month - 1),
        );

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dashboardProvider.loadError != null)
                    Container(
                      margin: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        0,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: AppSpacing.roundedLg,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(dashboardProvider.loadError!)),
                          TextButton.icon(
                            onPressed: dashboardProvider.isLoading
                                ? null
                                : dashboardProvider.retryCloudLoad,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  // 1. Header (App name, personalized greeting, month/year, notification icon)
                  DashboardHeader(
                    userName: dashboardProvider.fullName.isEmpty
                        ? 'there'
                        : dashboardProvider.fullName,
                    selectedMonth: selectedMonth,
                    onAddTransaction: onAddTransaction,
                    onNotificationTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No new notifications right now.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),

                  // 2. Month Selector (switch between months)
                  MonthSelector(
                    selectedMonth: selectedMonth,
                    onPreviousMonth: dashboardProvider.previousMonth,
                    onNextMonth: dashboardProvider.nextMonth,
                    onSelectMonth: dashboardProvider.setSelectedMonth,
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // 3. Monthly Summary Card (Total Income, Total Expenses, Remaining Budget, Utilization %)
                  MonthlySummaryCard(
                    summary: summary,
                    previousMonthExpenses: previousMonthSummary.totalExpenses,
                    profileMonthlyIncome:
                        dashboardProvider.profileMonthlyIncome,
                    onAddIncome: onAddTransactionForType == null
                        ? onAddTransaction
                        : () => onAddTransactionForType!(false),
                    onAddExpense: onAddTransactionForType == null
                        ? onAddTransaction
                        : () => onAddTransactionForType!(true),
                    onTap: () {
                      SetBudgetDialog.show(
                        context,
                        targetMonth: selectedMonth,
                        currentBudget: summary.monthlyBudget,
                      );
                    },
                    onEditBudget: () {
                      SetBudgetDialog.show(
                        context,
                        targetMonth: selectedMonth,
                        currentBudget: summary.monthlyBudget,
                      );
                    },
                  ),

                  if (dashboardProvider.regularExpenses.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: AppSpacing.roundedLg,
                        border: Border.all(
                          color: Theme.of(context).dividerColor
                              .withValues(alpha: .35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Regular expenses',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(dashboardProvider.regularExpenses),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  SmartInsightsSection(
                    summary: summary,
                    previousMonth: previousMonthSummary,
                    savingsGoal: dashboardProvider.savingsGoal,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // 4. Category Spending Section (All 9 categories with icon, name, amount, %, progress)
                  CategorySpendingSection(
                    categorySpendings: summary.categorySpendings,
                    totalExpenses: summary.totalExpenses,
                  ),

                  // 5. Recent Transactions (Latest five transactions with icon, desc, cat name, date, amount)
                  RecentTransactionsSection(
                    transactions: summary.recentTransactions,
                    onSeeAll: onSeeAllTransactions,
                    onTransactionTap: (tx) {
                      // Optional tap on transaction
                    },
                  ),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
