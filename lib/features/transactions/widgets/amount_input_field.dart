import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';

/// Form field for numeric amount input with decimal validation and visual styling.
class AmountInputField extends StatelessWidget {
  final TextEditingController controller;
  final bool isExpense;
  final ValueChanged<String>? onChanged;

  const AmountInputField({
    super.key,
    required this.controller,
    required this.isExpense,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryAmountColor = isExpense
        ? (isDark ? AppColors.darkExpense : AppColors.expense)
        : (isDark ? AppColors.darkIncome : AppColors.income);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: primaryAmountColor,
              letterSpacing: -0.5,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              prefixText: '${AppConstants.currencySymbol} ',
              prefixStyle: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: primaryAmountColor,
              ),
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkSubtleText : AppColors.subtleText,
              ),
            ),
            onChanged: onChanged,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an amount';
              }
              final parsed = double.tryParse(value.trim());
              if (parsed == null) {
                return 'Please enter a valid numeric amount';
              }
              if (parsed <= 0) {
                return 'Amount must be greater than zero';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
