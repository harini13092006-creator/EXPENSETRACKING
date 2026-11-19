import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/data/models/monthly_summary_model.dart';
import 'package:expensetracker/features/budget/widgets/set_budget_dialog.dart';

/// Monthly financial summary card with dynamic calculations for Remaining Budget
/// and Budget Utilization Percentage.
class MonthlySummaryCard extends StatelessWidget {
  final MonthlySummaryModel summary;
  final VoidCallback? onTap;
  final VoidCallback? onEditBudget;
  final double? previousMonthExpenses;
  final double profileMonthlyIncome;
  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;

  const MonthlySummaryCard({
    super.key,
    required this.summary,
    this.onTap,
    this.onEditBudget,
    this.previousMonthExpenses,
    this.profileMonthlyIncome = 0,
    this.onAddIncome,
    this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final utilizationPercent = summary.budgetUtilizationPercentage;
    final isOverBudget = summary.isOverBudget;

    // Progress bar color based on utilization
    Color progressColor;
    if (utilizationPercent > 90.0) {
      progressColor = AppColors.expense;
    } else if (utilizationPercent > 70.0) {
      progressColor = AppColors.warning;
    } else {
      progressColor = const Color(0xFF68E1A7);
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF153328), const Color(0xFF0F241C)]
              : [AppColors.primary, const Color(0xFF065F44)],
        ),
        borderRadius: AppSpacing.roundedXl,
        boxShadow: AppSpacing.cardElevation,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.roundedXl,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Remaining Budget & Utilization Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining Budget',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isOverBudget
                            ? AppColors.expense.withValues(alpha: 0.85)
                            : (summary.budgetAlertStatus ==
                                      BudgetAlertStatus.nearLimit
                                  ? AppColors.warning.withValues(alpha: 0.85)
                                  : (summary.budgetAlertStatus ==
                                            BudgetAlertStatus.moderate
                                        ? const Color(0xFF2563EB)
                                              .withValues(alpha: 0.85)
                                        : Colors.white.withValues(
                                            alpha: 0.18,
                                          ))),
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            summary.budgetAlertIcon,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            summary.budgetAlertLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // 2. Remaining Budget Value
                Text(
                  '${AppConstants.currencySymbol}${summary.remainingBudget.toStringAsFixed(2)}',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 3. Budget Utilization Progress Bar
                ClipRRect(
                  borderRadius: AppSpacing.roundedPill,
                  child: LinearProgressIndicator(
                    value: summary.budgetUtilizationRatio,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Budget: ${AppConstants.currencySymbol}${summary.monthlyBudget.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          key: const Key('edit_budget_button'),
                          onTap:
                              onEditBudget ??
                              () => SetBudgetDialog.show(
                                context,
                                targetMonth: summary.month,
                                currentBudget: summary.monthlyBudget,
                              ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: AppSpacing.roundedPill,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${utilizationPercent.toStringAsFixed(0)}% used',
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 4. Cash Flow Summary (Total Income & Total Expenses)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.15),
                    borderRadius: AppSpacing.roundedLg,
                  ),
                  child: Row(
                    children: [
                      // Total Income
                      Expanded(
                        child: Tooltip(
                          message: 'Add income',
                          child: InkWell(
                            key: const Key('add_income_from_summary'),
                            onTap: onAddIncome,
                            borderRadius: AppSpacing.roundedMd,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.income.withValues(
                                        alpha: 0.25,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_downward_rounded,
                                      color: Color(0xFF68E1A7),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Total Income',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.add_circle_outline_rounded,
                                              color: Colors.white.withValues(
                                                alpha: .8,
                                              ),
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '+${AppConstants.currencySymbol}${summary.totalIncome.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Divider
                      Container(
                        height: 34,
                        width: 1,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      // Total Expenses
                      Expanded(
                        child: Tooltip(
                          message: 'Add expense',
                          child: InkWell(
                            key: const Key('add_expense_from_summary'),
                            onTap: onAddExpense,
                            borderRadius: AppSpacing.roundedMd,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.expense.withValues(
                                        alpha: 0.25,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Color(0xFFFF8B8B),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                'Total Expenses',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.add_circle_outline_rounded,
                                              color: Colors.white.withValues(
                                                alpha: .8,
                                              ),
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '-${AppConstants.currencySymbol}${summary.totalExpenses.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF68E1A7),
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Daily average',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${AppConstants.currencySymbol}${summary.dailyAverage.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: Colors.white.withValues(alpha: .8),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Monthly income',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .75),
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${AppConstants.currencySymbol}${profileMonthlyIncome.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (previousMonthExpenses != null &&
                    previousMonthExpenses! > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        summary.totalExpenses >= previousMonthExpenses!
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "${(((summary.totalExpenses - previousMonthExpenses!) / previousMonthExpenses!) * 100).abs().toStringAsFixed(0)}% ${summary.totalExpenses >= previousMonthExpenses! ? 'above' : 'below'} last month's total",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
