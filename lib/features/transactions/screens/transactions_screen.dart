import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/core/widgets/custom_app_bar.dart';
import 'package:expensetracker/core/widgets/empty_state_widget.dart';
import 'package:expensetracker/core/widgets/transaction_tile.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/features/transactions/widgets/edit_transaction_sheet.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// Complete, responsive Transaction History screen featuring date grouping,
/// full-text search, multi-faceted filtering, swipe-to-delete with confirmation
/// and undo, tap-to-edit bottom sheet, and real-time SQLite persistence.
class TransactionsScreen extends StatefulWidget {
  final VoidCallback onAddTransaction;

  const TransactionsScreen({super.key, required this.onAddTransaction});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _selectedTypeIndex = 0; // 0: All, 1: Expenses, 2: Income
  String? _selectedCategoryId; // null = all categories
  DateTime? _selectedDateFilter; // null = all dates

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedTypeIndex = 0;
      _selectedCategoryId = null;
      _selectedDateFilter = null;
    });
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _selectedTypeIndex != 0 ||
      _selectedCategoryId != null ||
      _selectedDateFilter != null;

  String _formatTileSubtitle(DateTime date, String categoryName) {
    final timeStr = DateFormat('h:mm a').format(date);
    return '$timeStr • $categoryName';
  }

  String _getDateGroupTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDay = DateTime(date.year, date.month, date.day);

    if (txDay == today) {
      return 'Today';
    } else if (txDay == yesterday) {
      return 'Yesterday';
    } else if (txDay.year == now.year) {
      return DateFormat('EEEE, MMM d').format(date);
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    }
  }

  Map<DateTime, List<TransactionModel>> _groupTransactionsByDate(
    List<TransactionModel> transactions,
  ) {
    final Map<DateTime, List<TransactionModel>> grouped = {};
    for (final tx in transactions) {
      final dayKey = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (!grouped.containsKey(dayKey)) {
        grouped[dayKey] = [];
      }
      grouped[dayKey]!.add(tx);
    }
    return grouped;
  }

  Future<void> _pickDateFilter() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateFilter ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'FILTER TRANSACTIONS BY DATE',
    );

    if (picked != null) {
      setState(() {
        _selectedDateFilter = picked;
      });
    }
  }

  Future<bool> _confirmDelete(BuildContext context, TransactionModel tx) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedXl),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.expense,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Transaction?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${tx.description}"? This will update your balances and records in SQLite.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.darkSecondaryText
                : AppColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkSecondaryText
                    : AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
              shape: RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _handleDelete(DashboardProvider provider, TransactionModel tx) async {
    final deletedTx = tx;
    try {
      await provider.deleteTransaction(deletedTx.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete transaction: $error'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${deletedTx.description}"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.income,
          onPressed: () async {
            await provider.addTransaction(deletedTx);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final allTx = provider.allTransactions;

        // Apply filters
        List<TransactionModel> filtered = allTx;

        // 1. Type Filter (Expenses / Income)
        if (_selectedTypeIndex == 1) {
          filtered = filtered.where((t) => t.isExpense).toList();
        } else if (_selectedTypeIndex == 2) {
          filtered = filtered.where((t) => !t.isExpense).toList();
        }

        // 2. Category Filter
        if (_selectedCategoryId != null) {
          filtered = filtered
              .where((t) => t.category == _selectedCategoryId)
              .toList();
        }

        // 3. Date Filter
        if (_selectedDateFilter != null) {
          final filterDay = DateTime(
            _selectedDateFilter!.year,
            _selectedDateFilter!.month,
            _selectedDateFilter!.day,
          );
          filtered = filtered.where((t) {
            final txDay = DateTime(t.date.year, t.date.month, t.date.day);
            return txDay == filterDay;
          }).toList();
        }

        // 4. Search Filter
        final query = _searchController.text.trim().toLowerCase();
        if (query.isNotEmpty) {
          filtered = filtered.where((t) {
            return t.description.toLowerCase().contains(query) ||
                t.categoryItem.name.toLowerCase().contains(query);
          }).toList();
        }

        // Sort filtered transactions descending by date
        final sortedFiltered = List<TransactionModel>.from(filtered)
          ..sort((a, b) => b.date.compareTo(a.date));

        // Group by date: Today, Yesterday, Earlier dates
        final groupedTransactions = _groupTransactionsByDate(sortedFiltered);

        return Scaffold(
          appBar: CustomAppBar(
            title: 'Transactions',
            subtitle: 'Review & manage your spending',
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download_outlined, size: 22),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Exported ${sortedFiltered.length} transactions as CSV!',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                tooltip: 'Export CSV',
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.darkCard
                      : AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSpacing.roundedMd,
                    side: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by description or category...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.secondaryText,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),

              // 2. Type Filter Segment (All Activity / Expenses / Income)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Container(
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
                      _FilterSegment(
                        label: 'All Activity',
                        isSelected: _selectedTypeIndex == 0,
                        onTap: () => setState(() => _selectedTypeIndex = 0),
                      ),
                      _FilterSegment(
                        label: 'Expenses',
                        isSelected: _selectedTypeIndex == 1,
                        onTap: () => setState(() => _selectedTypeIndex = 1),
                      ),
                      _FilterSegment(
                        label: 'Income',
                        isSelected: _selectedTypeIndex == 2,
                        onTap: () => setState(() => _selectedTypeIndex = 2),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Category & Date Filter Chips
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  children: [
                    // All Categories Chip
                    ChoiceChip(
                      label: const Text('All Categories'),
                      selected: _selectedCategoryId == null,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategoryId = null);
                        }
                      },
                      selectedColor: isDark
                          ? AppColors.darkPrimary
                          : AppColors.primary,
                      labelStyle: TextStyle(
                        color: _selectedCategoryId == null
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark
                                  ? AppColors.darkPrimaryText
                                  : AppColors.primaryText),
                        fontSize: 12,
                        fontWeight: _selectedCategoryId == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Date Filter Chip
                    ActionChip(
                      avatar: Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: _selectedDateFilter != null
                            ? (isDark ? Colors.black : Colors.white)
                            : AppColors.secondaryText,
                      ),
                      label: Text(
                        _selectedDateFilter == null
                            ? 'All Dates'
                            : DateFormat('MMM d, yyyy')
                                  .format(_selectedDateFilter!),
                      ),
                      backgroundColor: _selectedDateFilter != null
                          ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                          : (isDark ? AppColors.darkCard : AppColors.surface),
                      labelStyle: TextStyle(
                        color: _selectedDateFilter != null
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark
                                  ? AppColors.darkPrimaryText
                                  : AppColors.primaryText),
                        fontSize: 12,
                        fontWeight: _selectedDateFilter != null
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      onPressed: _pickDateFilter,
                    ),

                    if (_selectedDateFilter != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Clear Date Filter',
                        onPressed: () =>
                            setState(() => _selectedDateFilter = null),
                      ),
                    ],

                    const SizedBox(width: 8),

                    // Category Specific Chips
                    ...(_selectedTypeIndex == 1
                            ? CategoryCatalog.expenseCategories
                            : _selectedTypeIndex == 2
                            ? CategoryCatalog.incomeCategories
                            : [
                                ...CategoryCatalog.expenseCategories,
                                ...CategoryCatalog.incomeCategories,
                              ])
                        .map((cat) {
                          final isSelected = _selectedCategoryId == cat.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(
                                cat.icon,
                                size: 14,
                                color: isSelected ? Colors.white : cat.color,
                              ),
                              label: Text(cat.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategoryId = selected
                                      ? cat.id
                                      : null;
                                });
                              },
                              selectedColor: cat.color,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                          ? AppColors.darkPrimaryText
                                          : AppColors.primaryText),
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                  ],
                ),
              ),

              // 4. Active Filters Status & Count Bar
              if (_hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Found ${sortedFiltered.length} matching transaction${sortedFiltered.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.secondaryText,
                        ),
                      ),
                      InkWell(
                        onTap: _clearAllFilters,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            'Reset All Filters',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 4),

              // 5. Grouped Transactions List or Empty State
              Expanded(
                child: allTx.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: 'No transactions yet',
                        description: 'You haven\'t recorded any expenses or income yet. Tap the button below to add your first transaction.',
                        actionText: 'Add Transaction',
                        onActionPressed: widget.onAddTransaction,
                      )
                    : sortedFiltered.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No transactions found',
                        description: 'No transactions matched your current filters or search query. Try resetting your search terms or filters.',
                        actionText: 'Reset Filters',
                        onActionPressed: _clearAllFilters,
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        itemCount: groupedTransactions.keys.length,
                        itemBuilder: (context, groupIndex) {
                          final dayKey = groupedTransactions.keys.elementAt(
                            groupIndex,
                          );
                          final txList = groupedTransactions[dayKey]!;
                          final groupTitle = _getDateGroupTitle(dayKey);

                          // Compute daily spending total for context
                          double dayExpense = 0;
                          double dayIncome = 0;
                          for (final t in txList) {
                            if (t.isExpense) {
                              dayExpense += t.amount;
                            } else {
                              dayIncome += t.amount;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date Section Header
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 14,
                                  bottom: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      groupTitle,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                            color: isDark
                                                ? AppColors.darkPrimaryText
                                                : AppColors.primaryText,
                                          ),
                                    ),
                                    Text(
                                      dayExpense > 0 && dayIncome > 0
                                          ? '-${AppConstants.currencySymbol}${dayExpense.toStringAsFixed(2)} | +${AppConstants.currencySymbol}${dayIncome.toStringAsFixed(2)}'
                                          : dayExpense > 0
                                          ? '-${AppConstants.currencySymbol}${dayExpense.toStringAsFixed(2)}'
                                          : '+${AppConstants.currencySymbol}${dayIncome.toStringAsFixed(2)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.darkSecondaryText
                                                : AppColors.secondaryText,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              // Dismissible transaction items for this day
                              ...txList.map((tx) {
                                return Dismissible(
                                  key: ValueKey(
                                    'tx_item_${tx.id}_${tx.date.millisecondsSinceEpoch}',
                                  ),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) =>
                                      _confirmDelete(context, tx),
                                  onDismissed: (_) =>
                                      _handleDelete(provider, tx),
                                  background: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.only(right: 20),
                                    decoration: BoxDecoration(
                                      color: AppColors.expense,
                                      borderRadius: AppSpacing.roundedLg,
                                    ),
                                    alignment: Alignment.centerRight,
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: TransactionTile(
                                    title: tx.description,
                                    subtitle: _formatTileSubtitle(
                                      tx.date,
                                      tx.categoryItem.name,
                                    ),
                                    amount: tx.amount,
                                    isExpense: tx.isExpense,
                                    category: tx.categoryItem,
                                    onTap: () =>
                                        EditTransactionSheet.show(context, tx),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterSegment extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedBg = isDark ? AppColors.darkPrimary : AppColors.primary;
    final selectedText = isDark ? Colors.black : Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: AppSpacing.roundedSm,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? selectedText
                  : (isDark
                        ? AppColors.darkSecondaryText
                        : AppColors.secondaryText),
            ),
          ),
        ),
      ),
    );
  }
}
