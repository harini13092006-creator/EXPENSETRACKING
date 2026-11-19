import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';

/// Interactive date selector field allowing users to pick current or past dates.
class DatePickerField extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const DatePickerField({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allows past and today
      helpText: 'SELECT TRANSACTION DATE',
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formatted = DateFormat('EEEE, MMM dd, yyyy').format(selectedDate);

    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    return Material(
      color: isDark ? AppColors.darkCard : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.roundedLg,
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkPrimary.withValues(alpha: 0.15)
                : AppColors.secondary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.calendar_today_rounded,
            color: isDark ? AppColors.darkPrimary : AppColors.primary,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(
              'Transaction Date',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.incomeLight,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(
                    color: AppColors.income,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            formatted,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
            ),
          ),
        ),
        trailing: const Icon(Icons.calendar_month_outlined, size: 20),
        onTap: () => _pickDate(context),
      ),
    );
  }
}
