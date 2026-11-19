import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/data/models/category_spending_model.dart';
import 'package:expensetracker/data/models/transaction_model.dart';

/// Budget alert status based on monthly spending percentage.
enum BudgetAlertStatus {
  normal, // Below 50%
  moderate, // 50% - 80%
  nearLimit, // 80% - 100%
  exceeded, // Above 100%
}

/// Aggregated monthly financial data model with dynamic calculations.
class MonthlySummaryModel {
  final DateTime month;
  final double totalIncome;
  final double totalExpenses;
  final double monthlyBudget;
  final List<CategorySpendingModel> categorySpendings;
  final List<TransactionModel> recentTransactions;

  const MonthlySummaryModel({
    required this.month,
    required this.totalIncome,
    required this.totalExpenses,
    required this.monthlyBudget,
    required this.categorySpendings,
    required this.recentTransactions,
  });

  /// Formula: Remaining Budget = Monthly Budget - Total Expenses
  double get remainingBudget => monthlyBudget - totalExpenses;

  /// Budget Usage Percentage: (Total Expenses / Monthly Budget) × 100.
  /// Safely handles zero budget without division by zero.
  double get budgetUsagePercentage {
    if (monthlyBudget <= 0) return 0.0;
    return (totalExpenses / monthlyBudget) * 100;
  }

  /// Backwards-compatible getter
  double get budgetUtilizationPercentage => budgetUsagePercentage;

  /// Utilization ratio for progress bars (0.0 to 1.0 clamped)
  double get budgetUtilizationRatio {
    if (monthlyBudget <= 0) return 0.0;
    final ratio = totalExpenses / monthlyBudget;
    return ratio.clamp(0.0, 1.0);
  }

  /// Indicates if spending has exceeded the budget
  bool get isOverBudget => totalExpenses > monthlyBudget;

  /// Budget alerts:
  /// - Below 50%: Normal.
  /// - 50–80%: Moderate spending.
  /// - 80–100%: Near budget limit.
  /// - Above 100%: Budget exceeded.
  BudgetAlertStatus get budgetAlertStatus {
    if (monthlyBudget <= 0) {
      return totalExpenses > 0
          ? BudgetAlertStatus.exceeded
          : BudgetAlertStatus.normal;
    }
    final usage = budgetUsagePercentage;
    if (usage > 100.0) return BudgetAlertStatus.exceeded;
    if (usage >= 80.0) return BudgetAlertStatus.nearLimit;
    if (usage >= 50.0) return BudgetAlertStatus.moderate;
    return BudgetAlertStatus.normal;
  }

  /// Human-readable label for budget alert status
  String get budgetAlertLabel {
    switch (budgetAlertStatus) {
      case BudgetAlertStatus.normal:
        return 'Normal';
      case BudgetAlertStatus.moderate:
        return 'Moderate spending';
      case BudgetAlertStatus.nearLimit:
        return 'Near budget limit';
      case BudgetAlertStatus.exceeded:
        return 'Budget exceeded';
    }
  }

  /// Alert color based on current spending threshold
  Color get budgetAlertColor {
    switch (budgetAlertStatus) {
      case BudgetAlertStatus.normal:
        return AppColors.income;
      case BudgetAlertStatus.moderate:
        return const Color(0xFF2563EB); // Vibrant blue
      case BudgetAlertStatus.nearLimit:
        return AppColors.warning;
      case BudgetAlertStatus.exceeded:
        return AppColors.expense;
    }
  }

  /// Alert icon based on current spending threshold
  IconData get budgetAlertIcon {
    switch (budgetAlertStatus) {
      case BudgetAlertStatus.normal:
        return Icons.check_circle_rounded;
      case BudgetAlertStatus.moderate:
        return Icons.info_rounded;
      case BudgetAlertStatus.nearLimit:
        return Icons.warning_amber_rounded;
      case BudgetAlertStatus.exceeded:
        return Icons.error_rounded;
    }
  }

  /// Top spending category for the month (highest non-zero expense)
  CategorySpendingModel? get topSpendingCategory {
    final active = categorySpendings.where((c) => c.amount > 0).toList();
    if (active.isEmpty) return null;
    return active.first; // Already sorted descending by amount
  }

  /// Net savings (Total Income - Total Expenses)
  double get netSavings => totalIncome - totalExpenses;

  /// Expenses divided by elapsed calendar days (or full days for past months).
  double get dailyAverage {
    final now = DateTime.now();
    final elapsedDays = month.year == now.year && month.month == now.month
        ? now.day
        : month.isBefore(DateTime(now.year, now.month))
        ? DateTime(month.year, month.month + 1, 0).day
        : 0;
    return elapsedDays == 0 ? 0 : totalExpenses / elapsedDays;
  }

  /// Savings rate percentage
  double get savingsRatePercentage {
    if (totalIncome <= 0) return 0.0;
    final rate = ((totalIncome - totalExpenses) / totalIncome) * 100;
    return rate;
  }
}
