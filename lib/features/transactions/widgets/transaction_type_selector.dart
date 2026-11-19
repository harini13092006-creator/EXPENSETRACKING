import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';

/// Segmented toggle selector for choosing between Expense and Income.
class TransactionTypeSelector extends StatelessWidget {
  final bool isExpense;
  final ValueChanged<bool> onTypeChanged;

  const TransactionTypeSelector({
    super.key,
    required this.isExpense,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Expense Button
          Expanded(
            child: GestureDetector(
              onTap: () => onTypeChanged(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isExpense
                      ? (isDark ? AppColors.darkExpense : AppColors.expense)
                      : Colors.transparent,
                  borderRadius: AppSpacing.roundedSm,
                  boxShadow: isExpense
                      ? [
                          BoxShadow(
                            color: AppColors.expense.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: isExpense
                          ? Colors.white
                          : (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Expense',
                      style: TextStyle(
                        color: isExpense
                            ? Colors.white
                            : (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText),
                        fontWeight: isExpense ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Income Button
          Expanded(
            child: GestureDetector(
              onTap: () => onTypeChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isExpense
                      ? (isDark ? AppColors.darkIncome : AppColors.income)
                      : Colors.transparent,
                  borderRadius: AppSpacing.roundedSm,
                  boxShadow: !isExpense
                      ? [
                          BoxShadow(
                            color: AppColors.income.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 18,
                      color: !isExpense
                          ? Colors.white
                          : (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Income',
                      style: TextStyle(
                        color: !isExpense
                            ? Colors.white
                            : (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText),
                        fontWeight: !isExpense ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
