import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';

/// Interactive month switcher component with previous/next controls and date picker.
class MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectMonth;

  const MonthSelector({
    super.key,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onSelectMonth,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'SELECT MONTH',
    );
    if (picked != null) {
      onSelectMonth(DateTime(picked.year, picked.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedMonth = DateFormat('MMMM yyyy').format(selectedMonth);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPreviousMonth,
            tooltip: 'Previous Month',
            visualDensity: VisualDensity.compact,
            color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
          ),
          InkWell(
            onTap: () => _pickDate(context),
            borderRadius: AppSpacing.roundedMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedMonth,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 20,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNextMonth,
            tooltip: 'Next Month',
            visualDensity: VisualDensity.compact,
            color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
          ),
        ],
      ),
    );
  }
}
