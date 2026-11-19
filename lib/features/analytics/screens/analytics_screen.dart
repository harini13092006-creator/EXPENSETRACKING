import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/widgets/custom_app_bar.dart';
import 'package:expensetracker/data/models/monthly_summary_model.dart';
import 'package:expensetracker/features/budget/widgets/set_budget_dialog.dart';
import 'package:expensetracker/features/dashboard/widgets/month_selector.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// Analytics & Reports screen showing dynamic spending breakdowns, trends,
/// fl_chart charts, category distributions, and budget alerts from SQLite.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _touchedPieIndex = -1;
  int _touchedBarIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final summary = provider.currentMonthSummary;
        final selectedMonth = provider.selectedMonth;
        final trends = provider.getRecentMonthlyTrends(monthsCount: 6);

        final activeSpendings = summary.categorySpendings.where((c) => c.amount > 0).toList();
        final hasExpenseData = summary.totalExpenses > 0;
        final topCategory = summary.topSpendingCategory;

        return Scaffold(
          appBar: CustomAppBar(
            title: 'Financial Analytics',
            subtitle: 'Real-time SQLite spending insights',
            actions: [
              IconButton(
                key: const Key('analytics_set_budget_action'),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 22),
                tooltip: 'Set Monthly Budget',
                onPressed: () {
                  SetBudgetDialog.show(
                    context,
                    targetMonth: selectedMonth,
                    currentBudget: summary.monthlyBudget,
                  );
                },
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.roundedMd,
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Month Selector Navigation
                MonthSelector(
                  selectedMonth: selectedMonth,
                  onPreviousMonth: provider.previousMonth,
                  onNextMonth: provider.nextMonth,
                  onSelectMonth: provider.setSelectedMonth,
                ),

                const SizedBox(height: AppSpacing.md),

                // 2. Budget Alert Banner Card
                _buildBudgetAlertCard(context, summary, selectedMonth, isDark),

                const SizedBox(height: AppSpacing.md),

                // 3. Income vs Expense Comparison Card
                _buildCashFlowComparisonCard(context, summary, isDark),

                const SizedBox(height: AppSpacing.md),

                // 4. Top Spending Category Card
                if (topCategory != null)
                  _buildTopCategoryCard(context, topCategory, summary.totalExpenses, isDark),

                if (topCategory != null) const SizedBox(height: AppSpacing.md),

                // 5. Category-wise Pie Chart (fl_chart)
                _buildCategoryPieChartSection(context, activeSpendings, hasExpenseData, summary.totalExpenses, isDark),

                const SizedBox(height: AppSpacing.md),

                // 6. Monthly Spending Trends Bar Chart (fl_chart)
                _buildMonthlyTrendChartSection(context, trends, selectedMonth, isDark),

                const SizedBox(height: AppSpacing.md),

                // 7. Category Percentages Breakdown List
                _buildCategoryPercentagesList(context, summary.categorySpendings, summary.totalExpenses, isDark),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Budget Alert Banner according to requirement thresholds:
  /// - Below 50%: Normal.
  /// - 50–80%: Moderate spending.
  /// - 80–100%: Near budget limit.
  /// - Above 100%: Budget exceeded.
  Widget _buildBudgetAlertCard(
    BuildContext context,
    MonthlySummaryModel summary,
    DateTime selectedMonth,
    bool isDark,
  ) {
    final alertColor = summary.budgetAlertColor;
    final alertIcon = summary.budgetAlertIcon;
    final alertLabel = summary.budgetAlertLabel;
    final usagePercent = summary.budgetUsagePercentage;

    String alertDescription;
    switch (summary.budgetAlertStatus) {
      case BudgetAlertStatus.normal:
        alertDescription = 'Healthy spending. You have preserved plenty of budget.';
        break;
      case BudgetAlertStatus.moderate:
        alertDescription = 'Spending is at a moderate level for this month.';
        break;
      case BudgetAlertStatus.nearLimit:
        alertDescription = 'Approaching your spending limit. Monitor discretionary expenses.';
        break;
      case BudgetAlertStatus.exceeded:
        alertDescription = 'Budget exceeded by ${AppConstants.currencySymbol}${(summary.totalExpenses - summary.monthlyBudget).toStringAsFixed(2)}.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(
          color: alertColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: AppSpacing.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(alertIcon, color: alertColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          alertLabel,
                          key: const Key('budget_alert_label'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: alertColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: alertColor.withValues(alpha: 0.15),
                            borderRadius: AppSpacing.roundedPill,
                          ),
                          child: Text(
                            '${usagePercent.toStringAsFixed(1)}% used',
                            key: const Key('budget_usage_percent_text'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: alertColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alertDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('edit_budget_dialog_button'),
                onPressed: () {
                  SetBudgetDialog.show(
                    context,
                    targetMonth: selectedMonth,
                    currentBudget: summary.monthlyBudget,
                  );
                },
                child: const Text('Edit Budget'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppSpacing.roundedPill,
            child: LinearProgressIndicator(
              value: summary.budgetUtilizationRatio,
              backgroundColor: isDark ? AppColors.darkBorder : AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(alertColor),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget: ${AppConstants.currencySymbol}${summary.monthlyBudget.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                ),
              ),
              Text(
                'Remaining: ${AppConstants.currencySymbol}${summary.remainingBudget.toStringAsFixed(2)}',
                key: const Key('remaining_budget_text'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: summary.remainingBudget < 0 ? AppColors.expense : (isDark ? AppColors.darkPrimaryText : AppColors.primaryText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cash Flow comparison: Total Income vs Total Expenses with Net Savings
  Widget _buildCashFlowComparisonCard(
    BuildContext context,
    MonthlySummaryModel summary,
    bool isDark,
  ) {
    final netSavings = summary.netSavings;
    final isPositive = netSavings >= 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
        boxShadow: AppSpacing.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Income vs Expenses',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isPositive ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${summary.savingsRatePercentage.toStringAsFixed(1)}% savings rate',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPositive ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // Income Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.incomeLight.withValues(alpha: isDark ? 0.2 : 0.6),
                    borderRadius: AppSpacing.roundedLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_downward_rounded, color: AppColors.income, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Total Income',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.income,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppConstants.currencySymbol}${summary.totalIncome.toStringAsFixed(2)}',
                        key: const Key('total_income_text'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Expense Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.expenseLight.withValues(alpha: isDark ? 0.2 : 0.6),
                    borderRadius: AppSpacing.roundedLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded, color: AppColors.expense, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Total Expenses',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppConstants.currencySymbol}${summary.totalExpenses.toStringAsFixed(2)}',
                        key: const Key('total_expenses_text'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Net Savings footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Monthly Balance',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                ),
              ),
              Text(
                '${isPositive ? '+' : ''}${AppConstants.currencySymbol}${netSavings.toStringAsFixed(2)}',
                key: const Key('net_savings_text'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Top spending category highlight card
  Widget _buildTopCategoryCard(
    BuildContext context,
    dynamic topCategory,
    double totalExpenses,
    bool isDark,
  ) {
    final cat = topCategory.category;
    final amount = topCategory.amount as double;
    final percentage = totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
        boxShadow: AppSpacing.subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(cat.icon, color: cat.color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      'TOP SPENDING CATEGORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  cat.name,
                  key: const Key('top_spending_category_name'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}% of total monthly expenses',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
            key: const Key('top_spending_category_amount'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  /// Category-wise Pie Chart implemented using fl_chart
  Widget _buildCategoryPieChartSection(
    BuildContext context,
    List<dynamic> activeSpendings,
    bool hasExpenseData,
    double totalExpenses,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
        boxShadow: AppSpacing.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Proportion of expenses by category',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!hasExpenseData)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 48,
                      color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No expenses recorded for this month',
                      style: TextStyle(
                        color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedPieIndex = -1;
                          return;
                        }
                        _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: List.generate(activeSpendings.length, (i) {
                    final item = activeSpendings[i];
                    final isTouched = i == _touchedPieIndex;
                    final radius = isTouched ? 60.0 : 50.0;
                    final percent = (item.amount / totalExpenses) * 100;

                    return PieChartSectionData(
                      color: item.category.color,
                      value: item.amount,
                      title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
                      radius: radius,
                      titleStyle: TextStyle(
                        fontSize: isTouched ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: activeSpendings.map((item) {
                final percent = (item.amount / totalExpenses) * 100;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.category.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item.category.name} (${percent.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Monthly spending trends bar chart implemented using fl_chart
  Widget _buildMonthlyTrendChartSection(
    BuildContext context,
    List<MonthlyTrendData> trends,
    DateTime selectedMonth,
    bool isDark,
  ) {
    double maxExpense = 100.0;
    for (final t in trends) {
      if (t.totalExpenses > maxExpense) maxExpense = t.totalExpenses;
    }
    final maxY = maxExpense * 1.25;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: AppSpacing.roundedXl,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
        boxShadow: AppSpacing.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Spending Trends',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                ),
              ),
              Text(
                'Last 6 months',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dynamic expense history from SQLite',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => isDark ? AppColors.darkBorder : AppColors.primaryText,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = trends[groupIndex];
                      return BarTooltipItem(
                        '${item.monthLabel}\n${AppConstants.currencySymbol}${rod.toY.toStringAsFixed(2)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  touchCallback: (FlTouchEvent event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.spot == null) {
                        _touchedBarIndex = -1;
                        return;
                      }
                      _touchedBarIndex = response.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        if (value == meta.max) return const SizedBox.shrink();
                        return Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(0)}k'
                              : value.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < trends.length) {
                          final isCurrent = trends[idx].month.month == selectedMonth.month &&
                              trends[idx].month.year == selectedMonth.year;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              trends[idx].monthLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                                color: isCurrent
                                    ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                    : (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: (isDark ? AppColors.darkBorder : AppColors.divider).withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(trends.length, (i) {
                  final t = trends[i];
                  final isCurrentMonth = t.month.month == selectedMonth.month &&
                      t.month.year == selectedMonth.year;
                  final isTouched = i == _touchedBarIndex;

                  Color barColor;
                  if (isCurrentMonth) {
                    barColor = isDark ? AppColors.darkPrimary : AppColors.primary;
                  } else {
                    barColor = (isDark ? AppColors.darkPrimary : AppColors.primary).withValues(alpha: 0.45);
                  }

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: t.totalExpenses,
                        color: barColor,
                        width: isTouched ? 18 : 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: (isDark ? AppColors.darkBorder : AppColors.divider).withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Category Percentages Breakdown List
  /// Formula: Category Percentage = (Category Expense / Total Expenses) × 100.
  Widget _buildCategoryPercentagesList(
    BuildContext context,
    List<dynamic> categorySpendings,
    double totalExpenses,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spending by Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Exact percentage calculated dynamically for each category',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...categorySpendings.map((item) {
          final cat = item.category;
          final amount = item.amount as double;
          final percentage = totalExpenses > 0 ? (amount / totalExpenses) * 100 : 0.0;
          final progressRatio = totalExpenses > 0 ? (amount / totalExpenses).clamp(0.0, 1.0) : 0.0;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surface,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(cat.icon, color: cat.color, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}% of total spent',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: AppSpacing.roundedPill,
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    backgroundColor: isDark ? AppColors.darkBorder : AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(cat.color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
