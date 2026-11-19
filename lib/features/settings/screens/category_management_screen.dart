import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_spacing.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  static const _icons = [
    Icons.restaurant,
    Icons.receipt_long,
    Icons.shopping_bag,
    Icons.directions_car,
    Icons.medical_services,
    Icons.movie,
    Icons.school,
    Icons.flight,
    Icons.category,
    Icons.home,
    Icons.pets,
    Icons.sports,
    Icons.work,
    Icons.payments,
  ];
  static const _colors = [
    Color(0xFF087F5B),
    Color(0xFF13B8A6),
    Color(0xFFF97316),
    Color(0xFF0284C7),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFFEAB308),
    Color(0xFF64748B),
  ];

  Future<void> _edit(BuildContext context, {CategoryItem? category}) async {
    final name = TextEditingController(text: category?.name ?? '');
    final budget = TextEditingController(
      text: (category?.monthlyBudget ?? 0) == 0
          ? ''
          : category!.monthlyBudget.toStringAsFixed(2),
    );
    var isExpense = category?.isExpense ?? true;
    var icon = category?.icon ?? _icons.first;
    var color = category?.color ?? _colors.first;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'New category' : 'Edit category'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  if (category == null)
                    DropdownButtonFormField<bool>(
                      value: isExpense,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Expense')),
                        DropdownMenuItem(value: false, child: Text('Income')),
                      ],
                      onChanged: (value) {
                        if (value != null)
                          setDialogState(() => isExpense = value);
                      },
                    ),
                  TextField(
                    controller: budget,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monthly category budget (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _icons
                        .map(
                          (item) => IconButton(
                            onPressed: () => setDialogState(() => icon = item),
                            color: icon == item ? color : null,
                            icon: Icon(item),
                            tooltip: 'Choose icon',
                          ),
                        )
                        .toList(),
                  ),
                  Wrap(
                    spacing: 8,
                    children: _colors
                        .map(
                          (item) => InkWell(
                            onTap: () => setDialogState(() => color = item),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: item,
                              child: color == item
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == true && name.text.trim().isNotEmpty) {
      final id =
          category?.id ??
          '${name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${DateTime.now().microsecondsSinceEpoch}';
      try {
        await context.read<DashboardProvider>().updateCategory(
          CategoryItem(
            id: id,
            name: name.text.trim(),
            icon: icon,
            color: color,
            backgroundColor: color.withValues(alpha: .12),
            isExpense: category?.isExpense ?? isExpense,
            monthlyBudget: double.tryParse(budget.text) ?? 0,
          ),
          monthlyBudget: double.tryParse(budget.text) ?? 0,
        );
      } catch (_) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save category.')),
          );
      }
    }
    name.dispose();
    budget.dispose();
  }

  Future<void> _delete(BuildContext context, CategoryItem category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete ${category.name}? Existing transactions keep their category reference.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await context.read<DashboardProvider>().deleteCategory(category.id);
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete category.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Manage Categories')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(context),
      icon: const Icon(Icons.add),
      label: const Text('Category'),
    ),
    body: Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final categories = provider.categories;
        if (!provider.categoriesLoaded && provider.isCloudBacked)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final isExpense in [true, false]) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  isExpense ? 'Expenses' : 'Income',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final category in categories.where(
                (item) => item.isExpense == isExpense,
              ))
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: category.color.withValues(alpha: .12),
                      child: Icon(category.icon, color: category.color),
                    ),
                    title: Text(category.name),
                    subtitle: Text(
                      category.monthlyBudget > 0
                          ? 'Monthly budget: ${category.monthlyBudget.toStringAsFixed(2)}'
                          : 'No category budget',
                    ),
                    onTap: () => _edit(context, category: category),
                    trailing: IconButton(
                      tooltip: 'Delete ${category.name}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, category),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 88),
          ],
        );
      },
    ),
  );
}
