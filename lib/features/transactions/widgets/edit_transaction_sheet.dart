import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/core/widgets/app_buttons.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/features/transactions/widgets/amount_input_field.dart';
import 'package:expensetracker/features/transactions/widgets/category_selector_grid.dart';
import 'package:expensetracker/features/transactions/widgets/date_picker_field.dart';
import 'package:expensetracker/features/transactions/widgets/transaction_type_selector.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// Modal bottom sheet for viewing and updating an existing transaction's details.
class EditTransactionSheet extends StatefulWidget {
  final TransactionModel transaction;

  const EditTransactionSheet({super.key, required this.transaction});

  /// Helper to open the edit sheet directly from any context.
  static Future<bool?> show(
    BuildContext context,
    TransactionModel transaction,
  ) {
    final dashboard = context.read<DashboardProvider>();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChangeNotifierProvider<DashboardProvider>.value(
        value: dashboard,
        child: EditTransactionSheet(transaction: transaction),
      ),
    );
  }

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late bool _isExpense;
  late DateTime _selectedDate;
  late String _selectedCategoryId;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _noteController;
  late String _paymentMethod;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isExpense = widget.transaction.isExpense;
    _selectedDate = widget.transaction.date;
    _selectedCategoryId = widget.transaction.category;
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: widget.transaction.description,
    );
    _noteController = TextEditingController(text: widget.transaction.note);
    _paymentMethod = widget.transaction.paymentMethod;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onTypeChanged(bool isExpense) {
    if (_isExpense != isExpense) {
      setState(() {
        _isExpense = isExpense;
        _selectedCategoryId = isExpense
            ? CategoryCatalog.food.id
            : CategoryCatalog.salary.id;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amountParsed = double.tryParse(_amountController.text.trim());
    if (amountParsed == null || amountParsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount must be a positive number greater than 0'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedCategoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final availableCategories = Provider.of<DashboardProvider>(
      context,
      listen: false,
    ).categories.where((item) => item.id == _selectedCategoryId).toList();
    final updatedTx = widget.transaction.copyWith(
      type: _isExpense ? 'expense' : 'income',
      amount: amountParsed,
      description: _descriptionController.text.trim(),
      category: _selectedCategoryId,
      date: _selectedDate,
      paymentMethod: _paymentMethod,
      note: _noteController.text.trim(),
      categoryName: availableCategories.isEmpty
          ? widget.transaction.categoryName
          : availableCategories.first.name,
    );

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    try {
      await provider.updateTransaction(updatedTx);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = error is FirebaseException
          ? 'Could not update transaction (${error.code}). ${error.message ?? ''}'
          : 'Could not update transaction. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Transaction updated to ${AppConstants.currencySymbol}${amountParsed.toStringAsFixed(2)}',
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = context
        .watch<DashboardProvider>()
        .categories
        .where((category) => category.isExpense == _isExpense)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Transaction',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkPrimaryText
                                : AppColors.primaryText,
                          ),
                        ),
                        Text(
                          'Update record details saved in SQLite',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Type toggle
                TransactionTypeSelector(
                  isExpense: _isExpense,
                  onTypeChanged: _onTypeChanged,
                ),

                const SizedBox(height: AppSpacing.md),

                // Amount
                AmountInputField(
                  controller: _amountController,
                  isExpense: _isExpense,
                ),

                const SizedBox(height: AppSpacing.md),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'e.g. Grocery Store, Client Payout',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description cannot be empty';
                    }
                    if (value.trim().length < 2) {
                      return 'Description must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                // Date Picker
                DatePickerField(
                  selectedDate: _selectedDate,
                  onDateSelected: (newDate) {
                    setState(() {
                      _selectedDate = newDate;
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    prefixIcon: Icon(Icons.payment_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Bank transfer'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _paymentMethod = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Category Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Category *',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkPrimaryText
                            : AppColors.primaryText,
                      ),
                    ),
                    Text(
                      '${categories.length} available',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                CategorySelectorGrid(
                  categories: categories,
                  selectedCategoryId: _selectedCategoryId,
                  onSelectCategory: (cat) {
                    setState(() {
                      _selectedCategoryId = cat.id;
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: 'Cancel',
                        onPressed: () => Navigator.of(context).pop(false),
                        height: 50,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: PrimaryButton(
                        text: 'Save Changes',
                        icon: Icons.check_rounded,
                        isLoading: _isSaving,
                        onPressed: _saveChanges,
                        height: 50,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
