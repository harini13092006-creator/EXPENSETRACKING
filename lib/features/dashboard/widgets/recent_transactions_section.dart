import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/data/models/transaction_model.dart';

/// Section displaying the latest five transactions with icon, description, category, date, and amount.
class RecentTransactionsSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  final VoidCallback onSeeAll;
  final ValueChanged<TransactionModel>? onTransactionTap;

  const RecentTransactionsSection({
    super.key,
    required this.transactions,
    required this.onSeeAll,
    this.onTransactionTap,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (txDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Transactions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                ),
              ),
              TextButton(
                onPressed: onSeeAll,
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Transaction Items
          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.surface,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'No transactions in this month',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                final cat = tx.categoryItem;

                final amountColor = tx.isExpense
                    ? (isDark ? AppColors.darkExpense : AppColors.expense)
                    : (isDark ? AppColors.darkIncome : AppColors.income);
                final sign = tx.isExpense ? '-' : '+';

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.surface,
                    borderRadius: AppSpacing.roundedLg,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTransactionTap?.call(tx),
                      borderRadius: AppSpacing.roundedLg,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // 1. Category Icon
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? cat.color.withValues(alpha: 0.15)
                                    : cat.backgroundColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                cat.icon,
                                color: cat.color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),

                            // 2. Description, Category Name, and Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tx.description,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isDark
                                          ? AppColors.darkPrimaryText
                                          : AppColors.primaryText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(
                                        cat.name,
                                        style: TextStyle(
                                          color: cat.color,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        ' • ${_formatDate(tx.date)}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: isDark
                                              ? AppColors.darkSecondaryText
                                              : AppColors.secondaryText,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),

                            // 3. Amount
                            Text(
                              '$sign${AppConstants.currencySymbol}${tx.amount.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: amountColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
