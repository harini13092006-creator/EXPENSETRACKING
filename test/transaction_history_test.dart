import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/data/models/budget_model.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/data/repositories/budget_repository.dart';
import 'package:expensetracker/data/repositories/transaction_repository.dart';
import 'package:expensetracker/features/transactions/screens/transactions_screen.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

class MockTransactionRepo implements TransactionRepository {
  final List<TransactionModel> storage;

  MockTransactionRepo([List<TransactionModel>? initial])
      : storage = initial != null ? List.from(initial) : [];

  @override
  Future<List<TransactionModel>> getAllTransactions() async => List.from(storage);

  @override
  Future<List<TransactionModel>> getMonthlyTransactions(int month, int year) async {
    return storage.where((t) => t.date.month == month && t.date.year == year).toList();
  }

  @override
  Future<TransactionModel?> getTransactionById(int id) async {
    final matches = storage.where((t) => t.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<int> insertTransaction(TransactionModel transaction) async {
    final nextId = storage.length + 1;
    final item = transaction.copyWith(id: transaction.id ?? nextId);
    storage.add(item);
    return item.id ?? nextId;
  }

  @override
  Future<void> addTransaction(TransactionModel transaction) async {
    await insertTransaction(transaction);
  }

  @override
  Future<int> deleteTransaction(dynamic id) async {
    storage.removeWhere((t) => t.id?.toString() == id.toString());
    return 1;
  }

  @override
  Future<int> updateTransaction(TransactionModel transaction) async {
    final index = storage.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      storage[index] = transaction;
      return 1;
    }
    return 0;
  }

  @override
  Future<Map<String, double>> getCategoryExpenseTotals(int month, int year) async {
    final map = <String, double>{};
    for (final t in storage) {
      if (t.isExpense && t.date.month == month && t.date.year == year) {
        map[t.category] = (map[t.category] ?? 0.0) + t.amount;
      }
    }
    return map;
  }

  @override
  Future<Map<String, double>> getAllCategoryExpenseTotals() async {
    final map = <String, double>{};
    for (final t in storage) {
      if (t.isExpense) {
        map[t.category] = (map[t.category] ?? 0.0) + t.amount;
      }
    }
    return map;
  }
}

class MockBudgetRepo implements BudgetRepository {
  final List<BudgetModel> storage = [];

  @override
  Future<BudgetModel?> getBudget(int month, int year) async {
    final matches = storage.where((b) => b.month == month && b.year == year);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<int> setBudget(BudgetModel budget) async {
    storage.removeWhere((b) => b.month == budget.month && b.year == budget.year);
    storage.add(budget);
    return 1;
  }

  @override
  Future<List<BudgetModel>> getAllBudgets() async => List.from(storage);
}

void main() {
  group('Transaction History Screen Features Tests', () {
    late MockTransactionRepo txRepo;
    late MockBudgetRepo budgetRepo;
    late DashboardProvider provider;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 14, 0);
    final yesterday = today.subtract(const Duration(days: 1));
    final earlier = today.subtract(const Duration(days: 5));

    setUp(() {
      txRepo = MockTransactionRepo([
        TransactionModel(
          id: 101,
          type: 'expense',
          amount: 45.0,
          description: 'Lunch at Bistro',
          category: CategoryCatalog.food.id,
          date: today,
        ),
        TransactionModel(
          id: 102,
          type: 'income',
          amount: 1500.0,
          description: 'Freelance Design',
          category: CategoryCatalog.freelance.id,
          date: yesterday,
        ),
        TransactionModel(
          id: 103,
          type: 'expense',
          amount: 85.0,
          description: 'Electric Utility Bill',
          category: CategoryCatalog.bills.id,
          date: earlier,
        ),
      ]);
      budgetRepo = MockBudgetRepo();
      provider = DashboardProvider(
        repository: txRepo,
        budgetRepository: budgetRepo,
      );
    });

    Widget createScreen({VoidCallback? onAdd}) {
      return ChangeNotifierProvider<DashboardProvider>.value(
        value: provider,
        child: MaterialApp(
          home: TransactionsScreen(
            onAddTransaction: onAdd ?? () {},
          ),
        ),
      );
    }

    testWidgets('1 & 2. Renders transaction list grouped by Today, Yesterday, and Earlier dates',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Check group headers
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);

      // Check transaction descriptions
      expect(find.text('Lunch at Bistro'), findsOneWidget);
      expect(find.text('Freelance Design'), findsOneWidget);
      expect(find.text('Electric Utility Bill'), findsOneWidget);

      // Check formatted amounts
      expect(find.text(r'-$45.00'), findsWidgets);
      expect(find.text(r'+$1500.00'), findsWidgets);
      expect(find.text(r'-$85.00'), findsWidgets);
    });

    testWidgets('3. Edit Transaction bottom sheet opens, updates fields, and saves to SQLite',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Tap the Lunch at Bistro transaction to edit
      await tester.tap(find.text('Lunch at Bistro'));
      await tester.pumpAndSettle();

      // Verify edit sheet opened with pre-populated values
      expect(find.text('Edit Transaction'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Edit description and amount
      final descField = find.widgetWithText(TextFormField, 'Lunch at Bistro');
      await tester.enterText(descField, 'Fancy Dinner at Bistro');

      // Save changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify bottom sheet closed and description updated in list
      expect(find.text('Fancy Dinner at Bistro'), findsOneWidget);
      expect(find.text('Lunch at Bistro'), findsNothing);

      // Verify persisted in SQLite repository
      final updatedInDb = await txRepo.getTransactionById(101);
      expect(updatedInDb?.description, 'Fancy Dinner at Bistro');
    });

    testWidgets('4. Swipe-to-delete shows confirmation dialog and allows undo', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      expect(find.text('Lunch at Bistro'), findsOneWidget);

      // Swipe from right to left on Lunch at Bistro
      await tester.drag(find.text('Lunch at Bistro'), const Offset(-500.0, 0.0));
      await tester.pumpAndSettle();

      // Confirm Delete dialog must appear
      expect(find.text('Delete Transaction?'), findsOneWidget);

      // Tap Delete in dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // Verify removed from screen
      expect(find.text('Lunch at Bistro'), findsNothing);

      // Verify removed from repository
      expect(await txRepo.getTransactionById(101), isNull);

      // Verify UNDO SnackBar appears
      expect(find.text('UNDO'), findsOneWidget);

      // Tap UNDO
      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();

      // Verify restored on screen and repository
      expect(find.text('Lunch at Bistro'), findsOneWidget);
      expect(await txRepo.getAllTransactions(), hasLength(3));
    });

    testWidgets('5. Search by description filters transactions list', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Search for "Freelance"
      final searchInput = find.byType(TextField).first;
      await tester.enterText(searchInput, 'Freelance');
      await tester.pumpAndSettle();

      expect(find.text('Freelance Design'), findsOneWidget);
      expect(find.text('Lunch at Bistro'), findsNothing);
      expect(find.text('Electric Utility Bill'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Lunch at Bistro'), findsOneWidget);
      expect(find.text('Freelance Design'), findsOneWidget);
    });

    testWidgets('5b. Filter by Expense / Income segments', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Tap Expenses
      await tester.tap(find.text('Expenses'));
      await tester.pumpAndSettle();

      expect(find.text('Lunch at Bistro'), findsOneWidget);
      expect(find.text('Electric Utility Bill'), findsOneWidget);
      expect(find.text('Freelance Design'), findsNothing);

      // Tap Income
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(find.text('Freelance Design'), findsOneWidget);
      expect(find.text('Lunch at Bistro'), findsNothing);
      expect(find.text('Electric Utility Bill'), findsNothing);
    });

    testWidgets('5c. Filter by Category chip', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Tap Food category chip
      final foodChip = find.widgetWithText(ChoiceChip, 'Food');
      await tester.ensureVisible(foodChip);
      await tester.tap(foodChip);
      await tester.pumpAndSettle();

      expect(find.text('Lunch at Bistro'), findsOneWidget);
      expect(find.text('Freelance Design'), findsNothing);
      expect(find.text('Electric Utility Bill'), findsNothing);

      // Tap Food chip again to toggle off filter
      await tester.tap(foodChip);
      await tester.pumpAndSettle();

      expect(find.text('Freelance Design'), findsOneWidget);
      expect(find.text('Electric Utility Bill'), findsOneWidget);
    });

    testWidgets('6. Empty state displays when search/filter has zero matches with reset option',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createScreen());
      await tester.pumpAndSettle();

      // Search for non-existent keyword
      final searchInput = find.byType(TextField).first;
      await tester.enterText(searchInput, 'NonExistentProductXYZ');
      await tester.pumpAndSettle();

      expect(find.text('No transactions found'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      // Tap Reset Filters
      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Lunch at Bistro'), findsOneWidget);
    });

    testWidgets('6b. Empty state displays when storage is completely empty', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final emptyRepo = MockTransactionRepo([]);
      final emptyProvider = DashboardProvider(
        repository: emptyRepo,
        budgetRepository: budgetRepo,
      );

      bool addTapped = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<DashboardProvider>.value(
          value: emptyProvider,
          child: MaterialApp(
            home: TransactionsScreen(
              onAddTransaction: () => addTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Add Transaction'), findsOneWidget);

      await tester.tap(find.text('Add Transaction'));
      await tester.pumpAndSettle();
      expect(addTapped, isTrue);
    });
  });
}
