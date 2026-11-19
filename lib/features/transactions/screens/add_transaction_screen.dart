import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/core/widgets/app_buttons.dart';
import 'package:expensetracker/core/widgets/custom_app_bar.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/features/transactions/widgets/amount_input_field.dart';
import 'package:expensetracker/features/transactions/widgets/category_selector_grid.dart';
import 'package:expensetracker/features/transactions/widgets/date_picker_field.dart';
import 'package:expensetracker/features/transactions/widgets/transaction_type_selector.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// Complete, validated transaction creation screen supporting both Expense and Income
/// with SQLite persistence integration and live dashboard synchronization.
class AddTransactionScreen extends StatefulWidget {
  final DateTime? initialDate;
  final bool initialIsExpense;

  const AddTransactionScreen({
    super.key,
    this.initialDate,
    this.initialIsExpense = true,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isExpense = true;
  late DateTime _selectedDate;
  late String _selectedCategoryId;
  bool _isSubmitting = false;
  String _paymentMethod = 'other';

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isExpense = widget.initialIsExpense;
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedCategoryId = _isExpense
        ? CategoryCatalog.food.id
        : CategoryCatalog.salary.id;
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
        // Default category for new type
        _selectedCategoryId = isExpense
            ? CategoryCatalog.food.id
            : CategoryCatalog.salary.id;
      });
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _amountController.clear();
    _descriptionController.clear();
    _noteController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedCategoryId = _isExpense
          ? CategoryCatalog.food.id
          : CategoryCatalog.salary.id;
      _paymentMethod = 'other';
      _isSubmitting = false;
    });
  }

  Future<void> _submitTransaction() async {
    // 1. Run Form Validation
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Validate Amount specifically
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

    // 3. Validate Category Selection
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
      _isSubmitting = true;
    });

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final matchedCategories = provider.categories.where(
      (item) => item.id == _selectedCategoryId,
    );
    final categoryName = matchedCategories.isEmpty
        ? null
        : matchedCategories.first.name;
    final newTransaction = TransactionModel(
      description: _descriptionController.text.trim(),
      amount: amountParsed,
      date: _selectedDate,
      category: _selectedCategoryId,
      type: _isExpense ? 'expense' : 'income',
      createdAt: DateTime.now(),
      paymentMethod: _paymentMethod,
      note: _noteController.text.trim(),
      categoryName: categoryName,
    );

    // 4. Save to Provider & SQLite
    try {
      await provider.addTransaction(newTransaction);
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'none';
      final projectId = Firebase.apps.isEmpty
          ? 'unavailable'
          : Firebase.app().options.projectId;
      debugPrint(
        '[TransactionForm] save failed uid=$uid projectId=$projectId path=users/$uid/transactions operation=transaction.create errorType=${error.runtimeType}${error is FirebaseException ? ' FirebaseException.code=${error.code} plugin=${error.plugin}' : ''} message=$error\n$stackTrace',
      );
      final message = error is FirebaseException
          ? switch (error.code) {
              'permission-denied' => 'Firestore rules denied this transaction. Check users/{uid}/transactions in the deployed rules.',
              'unauthenticated' || 'user-changed' =>
                'Your sign-in is no longer active. Sign in again, then retry.',
              'unavailable' || 'network-request-failed' =>
                'Firestore is unavailable. Check your connection and retry.',
              _ =>
                'Save failed (${error.code}): ${error.message ?? 'No details returned.'}',
            }
          : 'Save failed (${error.runtimeType}): $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _submitTransaction(),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    // 5. Show Success Feedback
    final typeName = _isExpense ? 'Expense' : 'Income';
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
              '$typeName of ${AppConstants.currencySymbol}${amountParsed.toStringAsFixed(2)} saved!',
            ),
          ],
        ),
        backgroundColor: _isExpense ? AppColors.primary : AppColors.income,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // 6. Reset Form
    _resetForm();

    // 7. Return to Dashboard automatically
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allCategories = context.watch<DashboardProvider>().categories;
    final categories = allCategories
        .where((category) => category.isExpense == _isExpense)
        .toList();

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Add Transaction',
        subtitle: 'Record an expense or income entry',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Transaction Type Toggle (Expense / Income)
                TransactionTypeSelector(
                  isExpense: _isExpense,
                  onTypeChanged: _onTypeChanged,
                ),

                const SizedBox(height: AppSpacing.md),

                // 2. Numeric Amount Input
                AmountInputField(
                  controller: _amountController,
                  isExpense: _isExpense,
                ),

                const SizedBox(height: AppSpacing.md),

                // 3. Description Input Field
                TextFormField(
                  controller: _descriptionController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'e.g. Grocery Store, Uber Ride, Client Payout',
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

                // 4. Date Picker Field
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

                const SizedBox(height: AppSpacing.lg),

                // 5. Selectable Category Icons
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

                const SizedBox(height: AppSpacing.md),

                // 6. Optional Note Input
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Additional reference or tags...',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // 7. Save Transaction Button
                PrimaryButton(
                  text: 'Save Transaction',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: _isSubmitting,
                  onPressed: _submitTransaction,
                  height: 52,
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
