import 'package:flutter/material.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/data/models/category_spending_model.dart';

/// Section displaying breakdown of spending across all 9 standard categories.
class CategorySpendingSection extends StatefulWidget {
  final List<CategorySpendingModel> categorySpendings;
  final double totalExpenses;

  const CategorySpendingSection({
    super.key,
    required this.categorySpendings,
    required this.totalExpenses,
  });

  @override
  State<CategorySpendingSection> createState() =>
      _CategorySpendingSectionState();
}

class _CategorySpendingSectionState extends State<CategorySpendingSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter categories that have spending first, or fallback to full list
    final activeCategories = widget.categorySpendings
        .where((c) => c.amount > 0)
        .toList();
    final displayCategories = _showAll || activeCategories.length <= 4
        ? widget.categorySpendings
        : activeCategories.take(4).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category Spending',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkPrimaryText
                      : AppColors.primaryText,
                ),
              ),
              if (widget.categorySpendings.length > 4)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                  child: Text(_showAll ? 'Show Top' : 'View All (9)'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Category Cards
          if (widget.totalExpenses == 0)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.surface,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  'No expenses recorded for this month',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.secondaryText,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.surface,
                borderRadius: AppSpacing.roundedLg,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  width: 1,
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: displayCategories.length,
                separatorBuilder: (context, index) => const Divider(height: 20),
                itemBuilder: (context, index) {
                  final item = displayCategories[index];
                  final cat = item.category;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Category Icon
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? cat.color.withValues(alpha: 0.15)
                                  : cat.backgroundColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(cat.icon, color: cat.color, size: 18),
                          ),
                          const SizedBox(width: AppSpacing.md),

                          // Category Name & Percent
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDark
                                        ? AppColors.darkPrimaryText
                                        : AppColors.primaryText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.percentageDisplay.toStringAsFixed(1)}% ${item.percentageBasis}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.darkSecondaryText
                                        : AppColors.secondaryText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Amount Spent
                          Text(
                            '${AppConstants.currencySymbol}${item.amount.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isDark
                                  ? AppColors.darkPrimaryText
                                  : AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Progress Bar
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0,
                          end: item.percentage.clamp(0.0, 1.0),
                        ),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => ClipRRect(
                          borderRadius: AppSpacing.roundedPill,
                          child: LinearProgressIndicator(
                            value: value,
                            backgroundColor: isDark
                                ? AppColors.darkBorder
                                : AppColors.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cat.color,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
