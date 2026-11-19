import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// Modal dialog for setting and editing monthly spending budgets.
class SetBudgetDialog extends StatefulWidget {
  final DateTime targetMonth;
  final double currentBudget;

  const SetBudgetDialog({
    super.key,
    required this.targetMonth,
    required this.currentBudget,
  });

  /// Static helper method to display the dialog
  static Future<bool?> show(
    BuildContext context, {
    required DateTime targetMonth,
    required double currentBudget,
  }) {
    final dashboard = context.read<DashboardProvider>();
    return showDialog<bool>(
      context: context,
      builder: (context) => ChangeNotifierProvider<DashboardProvider>.value(
        value: dashboard,
        child: SetBudgetDialog(
          targetMonth: targetMonth,
          currentBudget: currentBudget,
        ),
      ),
    );
  }

  @override
  State<SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends State<SetBudgetDialog> {
  late final TextEditingController _amountController;
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedMonth;

  static const List<double> _quickPresets = [1000, 2500, 5000, 7500, 10000];

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.targetMonth;
    final formatted = widget.currentBudget > 0
        ? widget.currentBudget.toStringAsFixed(widget.currentBudget.truncateToDouble() == widget.currentBudget ? 0 : 2)
        : '';
    _amountController = TextEditingController(text: formatted);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _applyPreset(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final provider = Provider.of<DashboardProvider>(context, listen: false);

    await provider.setMonthlyBudget(
      parsedAmount,
      month: _selectedMonth.month,
      year: _selectedMonth.year,
    );

    if (mounted) {
      final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Budget for $monthName updated to ${AppConstants.currencySymbol}${parsedAmount.toStringAsFixed(2)}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedXl),
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkPrimary : AppColors.primary).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Budget',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                          ),
                        ),
                        Text(
                          monthName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Budget Amount Input Field
              Text(
                'Spending Limit',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                ),
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text(
                      AppConstants.currencySymbol,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  hintText: '0.00',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  filled: true,
                  fillColor: isDark ? AppColors.darkBackground : AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.roundedMd,
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppSpacing.roundedMd,
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppSpacing.roundedMd,
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a budget amount';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null) {
                    return 'Please enter a valid numeric amount';
                  }
                  if (parsed < 0) {
                    return 'Budget cannot be negative';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // Quick Preset Chips
              Text(
                'Quick Presets',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickPresets.map((amount) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          '${AppConstants.currencySymbol}${amount >= 1000 ? '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k' : amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                          ),
                        ),
                        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
                        side: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedPill),
                        onPressed: () => _applyPreset(amount),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    key: const Key('save_budget_button'),
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Save Budget',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
