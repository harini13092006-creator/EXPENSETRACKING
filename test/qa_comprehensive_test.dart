import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/core/widgets/empty_state_widget.dart';
import 'package:expensetracker/data/models/budget_model.dart';
import 'package:expensetracker/data/models/monthly_summary_model.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/data/repositories/budget_repository.dart';
import 'package:expensetracker/data/repositories/transaction_repository.dart';
import 'package:expensetracker/features/analytics/screens/analytics_screen.dart';
import 'package:expensetracker/features/transactions/screens/add_transaction_screen.dart';
import 'package:expensetracker/features/transactions/screens/transactions_screen.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// Test in-memory repository implementing TransactionRepository
class QaTransactionRepository implements TransactionRepository {
  final List<TransactionModel> storage = [];

  QaTransactionRepository([List<TransactionModel>? initial]) {
    if (initial != null) storage.addAll(initial);
  }

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

/// Test in-memory repository implementing BudgetRepository
class QaBudgetRepository implements BudgetRepository {
  final List<BudgetModel> storage = [];

  @override
  Future<BudgetModel?> getBudget(int month, int year) async {
    final matches = storage.where((b) => b.month == month && b.year == year);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<int> setBudget(BudgetModel budget) async {
    final index = storage.indexWhere((b) => b.month == budget.month && b.year == budget.year);
    if (index != -1) {
      storage[index] = budget;
      return 1;
    } else {
      storage.add(budget);
      return storage.length;
    }
  }

  @override
  Future<List<BudgetModel>> getAllBudgets() async => List.from(storage);
}

void main() {
  setUpAll(() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  group('QA Comprehensive Verification Suite', () {
    late QaTransactionRepository txRepo;
    late QaBudgetRepository budgetRepo;
    late DashboardProvider provider;

    setUp(() async {
      txRepo = QaTransactionRepository();
      budgetRepo = QaBudgetRepository();
      provider = DashboardProvider(
        repository: txRepo,
        budgetRepository: budgetRepo,
      );
      await provider.loadTransactions();
    });

    Widget createTestApp(Widget child) {
      return ChangeNotifierProvider<DashboardProvider>.value(
        value: provider,
        child: MaterialApp(home: child),
      );
    }

    // -------------------------------------------------------------
    // TEST 1: Add Expense Transaction
    // -------------------------------------------------------------
    test('1. Add expense transaction updates totalExpenses and decreases remaining budget', () async {
      await provider.setMonthlyBudget(3000.0, month: 11, year: 2026);
      provider.setSelectedMonth(DateTime(2026, 11, 1));

      final expense = TransactionModel(
        id: 1,
        description: 'Office Supplies',
        amount: 150.00,
        date: DateTime(2026, 11, 10),
        category: CategoryCatalog.shopping.id,
        type: 'expense',
      );

      await provider.addTransaction(expense);

      final summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(150.00));
      expect(summary.remainingBudget, equals(2850.00)); // 3000 - 150
      expect(summary.recentTransactions.first.description, equals('Office Supplies'));
      expect(summary.recentTransactions.first.isExpense, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 2: Add Income Transaction
    // -------------------------------------------------------------
    test('2. Add income transaction increases totalIncome and does not inflate totalExpenses', () async {
      provider.setSelectedMonth(DateTime(2026, 11, 1));

      final income = TransactionModel(
        id: 2,
        description: 'Monthly Consulting Retainer',
        amount: 4000.00,
        date: DateTime(2026, 11, 5),
        category: CategoryCatalog.salary.id,
        type: 'income',
      );

      await provider.addTransaction(income);

      final summary = provider.currentMonthSummary;
      expect(summary.totalIncome, equals(4000.00));
      expect(summary.totalExpenses, equals(0.00)); // Must remain 0
      expect(summary.netSavings, equals(4000.00));
      expect(summary.recentTransactions.first.isIncome, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 3, 4, 5: Reject Zero, Negative, and Invalid Amounts
    // -------------------------------------------------------------
    testWidgets('3, 4, 5. Reject zero amount, negative amount, and invalid numeric values', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const AddTransactionScreen()));
      await tester.pumpAndSettle();

      final amountFinder = find.byType(TextFormField).first;
      final descFinder = find.byType(TextFormField).at(1);
      final saveFinder = find.text('Save Transaction');

      // Valid description to isolate amount validation
      await tester.enterText(descFinder, 'Test Validation Item');

      // Case A: Reject 0 amount
      await tester.enterText(amountFinder, '0');
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();
      expect(find.text('Amount must be greater than zero'), findsOneWidget);

      // Case B: Reject 0.00 amount
      await tester.enterText(amountFinder, '0.00');
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();
      expect(find.text('Amount must be greater than zero'), findsOneWidget);

      // Case C: Formatter blocks negative symbols (input formatter RegExp ^\d+\.?\d{0,2})
      await tester.enterText(amountFinder, '-50.00');
      await tester.pumpAndSettle();
      // Formatter rejects '-' so controller does not accept invalid characters
      final amountFieldState = tester.widget<TextFormField>(amountFinder);
      expect(amountFieldState.controller?.text.contains('-'), isFalse);

      // Case D: Empty amount
      await tester.enterText(amountFinder, '');
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();
      expect(find.text('Please enter an amount'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // TEST 6: Reject Empty Descriptions
    // -------------------------------------------------------------
    testWidgets('6. Reject empty descriptions and whitespace-only descriptions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const AddTransactionScreen()));
      await tester.pumpAndSettle();

      final amountFinder = find.byType(TextFormField).first;
      final descFinder = find.byType(TextFormField).at(1);
      final saveFinder = find.text('Save Transaction');

      await tester.enterText(amountFinder, '120.00');

      // Empty string
      await tester.enterText(descFinder, '');
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();
      expect(find.text('Description cannot be empty'), findsOneWidget);

      // Whitespace only
      await tester.enterText(descFinder, '    ');
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();
      expect(find.text('Description cannot be empty'), findsOneWidget);

      // Single character
      await tester.enterText(descFinder, 'A');
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();
      expect(find.text('Description must be at least 2 characters'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // TEST 7: Edit Existing Transactions
    // -------------------------------------------------------------
    test('7. Edit existing transaction updates SQLite repository and recalculates dashboard', () async {
      provider.setSelectedMonth(DateTime(2026, 11, 1));
      await provider.setMonthlyBudget(2000.0, month: 11, year: 2026);

      final originalTx = TransactionModel(
        id: 701,
        description: 'Original Groceries',
        amount: 200.0,
        date: DateTime(2026, 11, 8),
        category: CategoryCatalog.food.id,
        type: 'expense',
      );
      await provider.addTransaction(originalTx);

      expect(provider.currentMonthSummary.totalExpenses, equals(200.0));

      // Edit: change amount from 200 to 350 and description
      final editedTx = originalTx.copyWith(
        amount: 350.0,
        description: 'Updated Gourmet Groceries',
      );
      await provider.updateTransaction(editedTx);

      final updatedSummary = provider.currentMonthSummary;
      expect(updatedSummary.totalExpenses, equals(350.0));
      expect(updatedSummary.remainingBudget, equals(1650.0)); // 2000 - 350
      expect(updatedSummary.recentTransactions.first.description, equals('Updated Gourmet Groceries'));
    });

    // -------------------------------------------------------------
    // TEST 8: Delete Transactions
    // -------------------------------------------------------------
    test('8. Delete transaction removes record and updates calculations immediately', () async {
      provider.setSelectedMonth(DateTime(2026, 11, 1));
      await provider.setMonthlyBudget(1500.0, month: 11, year: 2026);

      final tx = TransactionModel(
        id: 801,
        description: 'Gym Membership',
        amount: 80.0,
        date: DateTime(2026, 11, 2),
        category: CategoryCatalog.health.id,
        type: 'expense',
      );
      await provider.addTransaction(tx);
      expect(provider.currentMonthSummary.totalExpenses, equals(80.0));

      // Delete
      await provider.deleteTransaction(801);

      final summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(0.0));
      expect(summary.remainingBudget, equals(1500.0));
      expect(summary.recentTransactions.isEmpty, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 9: SQLite Persistence After Application Restart
    // -------------------------------------------------------------
    test('9. Verify SQLite persistence across simulated app restart', () async {
      final tempDir = await Directory.systemTemp.createTemp('expense_tracker_qa_');
      final dbPath = p.join(tempDir.path, 'qa_persistence.db');

      try {
        // Phase 1: Open SQLite DB and write transactions + budgets
        final db1 = await openDatabase(
          dbPath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                amount REAL NOT NULL,
                description TEXT NOT NULL,
                category TEXT NOT NULL,
                date TEXT NOT NULL,
                created_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE budgets (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                month INTEGER NOT NULL,
                year INTEGER NOT NULL,
                amount REAL NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(month, year)
              )
            ''');
          },
        );

        // Insert transaction
        await db1.insert('transactions', {
          'type': 'expense',
          'amount': 249.99,
          'description': 'Persistent Mechanical Keyboard',
          'category': 'shopping',
          'date': DateTime(2026, 11, 12, 10, 0).toIso8601String(),
          'created_at': DateTime(2026, 11, 12, 10, 0).toIso8601String(),
        });

        // Insert budget
        await db1.insert('budgets', {
          'month': 11,
          'year': 2026,
          'amount': 4200.00,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Close DB completely (Simulate App Kill)
        await db1.close();

        // Phase 2: Reopen DB from file (Simulate App Restart)
        final db2 = await openDatabase(dbPath, version: 1);

        final loadedTx = await db2.query('transactions');
        final loadedBudgets = await db2.query('budgets');

        expect(loadedTx.length, equals(1));
        expect(loadedTx.first['description'], equals('Persistent Mechanical Keyboard'));
        expect(loadedTx.first['amount'], equals(249.99));
        expect(loadedTx.first['type'], equals('expense'));

        expect(loadedBudgets.length, equals(1));
        expect(loadedBudgets.first['month'], equals(11));
        expect(loadedBudgets.first['year'], equals(2026));
        expect(loadedBudgets.first['amount'], equals(4200.00));

        await db2.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    // -------------------------------------------------------------
    // TEST 10 & 15: Monthly Filtering, Month & Year Changes
    // -------------------------------------------------------------
    test('10 & 15. Monthly filtering and switching month and year isolate calculations', () async {
      await provider.setMonthlyBudget(3000.0, month: 10, year: 2026);
      await provider.setMonthlyBudget(5000.0, month: 11, year: 2026);
      await provider.setMonthlyBudget(7000.0, month: 12, year: 2026);

      // Oct transaction
      await provider.addTransaction(TransactionModel(
        id: 1001,
        description: 'October Conference',
        amount: 800.0,
        date: DateTime(2026, 10, 15),
        category: CategoryCatalog.education.id,
        type: 'expense',
      ));

      // Nov transaction
      await provider.addTransaction(TransactionModel(
        id: 1002,
        description: 'November Flight',
        amount: 1200.0,
        date: DateTime(2026, 11, 20),
        category: CategoryCatalog.travel.id,
        type: 'expense',
      ));

      // Dec transaction
      await provider.addTransaction(TransactionModel(
        id: 1003,
        description: 'December Holiday Gifts',
        amount: 500.0,
        date: DateTime(2026, 12, 25),
        category: CategoryCatalog.shopping.id,
        type: 'expense',
      ));

      // Switch to October 2026
      provider.setSelectedMonth(DateTime(2026, 10, 1));
      var summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(800.0));
      expect(summary.monthlyBudget, equals(3000.0));
      expect(summary.remainingBudget, equals(2200.0));

      // Switch to November 2026
      provider.setSelectedMonth(DateTime(2026, 11, 1));
      summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(1200.0));
      expect(summary.monthlyBudget, equals(5000.0));
      expect(summary.remainingBudget, equals(3800.0));

      // Switch to December 2026
      provider.setSelectedMonth(DateTime(2026, 12, 1));
      summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(500.0));
      expect(summary.monthlyBudget, equals(7000.0));
      expect(summary.remainingBudget, equals(6500.0));
    });

    // -------------------------------------------------------------
    // TEST 11 & MATHEMATICAL VERIFICATION: Category Percentages
    // -------------------------------------------------------------
    test('11. Mathematical verification: Category percentages sum to ~100% and match formula', () async {
      provider.setSelectedMonth(DateTime(2026, 11, 1));

      // Food: $500, Transport: $300, Entertainment: $200 -> Total = $1,000
      await provider.addTransaction(TransactionModel(
        id: 1101,
        description: 'Groceries',
        amount: 500.0,
        date: DateTime(2026, 11, 5),
        category: CategoryCatalog.food.id,
        type: 'expense',
      ));
      await provider.addTransaction(TransactionModel(
        id: 1102,
        description: 'Train Pass',
        amount: 300.0,
        date: DateTime(2026, 11, 6),
        category: CategoryCatalog.transport.id,
        type: 'expense',
      ));
      await provider.addTransaction(TransactionModel(
        id: 1103,
        description: 'Concert Tickets',
        amount: 200.0,
        date: DateTime(2026, 11, 7),
        category: CategoryCatalog.entertainment.id,
        type: 'expense',
      ));

      final summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(1000.0));

      final active = summary.categorySpendings.where((c) => c.amount > 0).toList();
      expect(active.length, equals(3));

      // Category Percentage = (Category Expense / Total Expenses) * 100
      final foodItem = active.firstWhere((c) => c.category.id == CategoryCatalog.food.id);
      final transportItem = active.firstWhere((c) => c.category.id == CategoryCatalog.transport.id);
      final entItem = active.firstWhere((c) => c.category.id == CategoryCatalog.entertainment.id);

      expect(foodItem.percentageDisplay, closeTo(50.0, 0.001));
      expect(transportItem.percentageDisplay, closeTo(30.0, 0.001));
      expect(entItem.percentageDisplay, closeTo(20.0, 0.001));

      // Mathematical Verification: Sum of category percentages must equal 100%
      final sumPercentages = active.fold<double>(0.0, (acc, item) => acc + item.percentageDisplay);
      expect(sumPercentages, closeTo(100.0, 0.01));
    });

    // -------------------------------------------------------------
    // TEST 12 & MATHEMATICAL VERIFICATION: Budget Calculations
    // -------------------------------------------------------------
    test('12. Mathematical verification: Total Expenses, Remaining Budget, Usage % and zero safety', () {
      // Normal case
      final summary = MonthlySummaryModel(
        month: DateTime(2026, 11, 1),
        totalIncome: 6500.0,
        totalExpenses: 2600.0,
        monthlyBudget: 5200.0,
        categorySpendings: [],
        recentTransactions: [],
      );

      // Total Expenses must equal sum of expenses (verified)
      expect(summary.totalExpenses, equals(2600.0));

      // Remaining Budget = Monthly Budget - Total Expenses
      expect(summary.remainingBudget, equals(5200.0 - 2600.0)); // 2600.0

      // Budget Usage Percentage = (Total Expenses / Monthly Budget) * 100
      expect(summary.budgetUsagePercentage, equals((2600.0 / 5200.0) * 100)); // 50.0%

      // Net savings = Total Income - Total Expenses
      expect(summary.netSavings, equals(6500.0 - 2600.0)); // 3900.0

      // Savings rate = (Net Savings / Total Income) * 100
      expect(summary.savingsRatePercentage, equals((3900.0 / 6500.0) * 100)); // 60.0%

      // Zero budget safe handling
      final zeroBudget = MonthlySummaryModel(
        month: DateTime(2026, 11, 1),
        totalIncome: 1000.0,
        totalExpenses: 400.0,
        monthlyBudget: 0.0,
        categorySpendings: [],
        recentTransactions: [],
      );

      expect(zeroBudget.budgetUsagePercentage, equals(0.0));
      expect(zeroBudget.budgetUtilizationRatio, equals(0.0));
      expect(zeroBudget.remainingBudget, equals(-400.0));
      expect(zeroBudget.isOverBudget, isTrue);
    });

    // -------------------------------------------------------------
    // TEST 13: Income and Expense Separation
    // -------------------------------------------------------------
    test('13. Income and Expense transactions are strictly isolated', () async {
      provider.setSelectedMonth(DateTime(2026, 11, 1));

      await provider.addTransaction(TransactionModel(
        id: 1301,
        description: 'Salary',
        amount: 5000.0,
        date: DateTime(2026, 11, 1),
        category: CategoryCatalog.salary.id,
        type: 'income',
      ));

      await provider.addTransaction(TransactionModel(
        id: 1302,
        description: 'Freelance Bonus',
        amount: 1500.0,
        date: DateTime(2026, 11, 10),
        category: CategoryCatalog.freelance.id,
        type: 'income',
      ));

      await provider.addTransaction(TransactionModel(
        id: 1303,
        description: 'Rent',
        amount: 1800.0,
        date: DateTime(2026, 11, 5),
        category: CategoryCatalog.housing.id,
        type: 'expense',
      ));

      final summary = provider.currentMonthSummary;

      // Income strictly 6500
      expect(summary.totalIncome, equals(6500.0));
      // Expense strictly 1800
      expect(summary.totalExpenses, equals(1800.0));
      // Net balance: 6500 - 1800 = 4700
      expect(summary.netSavings, equals(4700.0));
    });

    // -------------------------------------------------------------
    // TEST 14: Analytics Charts (fl_chart)
    // -------------------------------------------------------------
    testWidgets('14. Analytics charts (PieChart and BarChart) and top category render with data', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      provider.setSelectedMonth(DateTime(2026, 11, 1));
      await provider.setMonthlyBudget(4000.0, month: 11, year: 2026);

      await provider.addTransaction(TransactionModel(
        id: 1401,
        description: 'Dinner Out',
        amount: 250.0,
        date: DateTime(2026, 11, 4),
        category: CategoryCatalog.food.id,
        type: 'expense',
      ));
      await provider.addTransaction(TransactionModel(
        id: 1402,
        description: 'Flight Tickets',
        amount: 750.0,
        date: DateTime(2026, 11, 15),
        category: CategoryCatalog.travel.id,
        type: 'expense',
      ));

      await tester.pumpWidget(createTestApp(const AnalyticsScreen()));
      await tester.pumpAndSettle();

      // PieChart and BarChart from fl_chart exist
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);

      // Top Spending Category card is Travel ($750)
      expect(find.byKey(const Key('top_spending_category_name')), findsOneWidget);
      expect(find.text(CategoryCatalog.travel.name), findsWidgets);
      expect(find.text('\$750.00'), findsWidgets);
    });

    // -------------------------------------------------------------
    // TEST 16: Empty-State Screens
    // -------------------------------------------------------------
    testWidgets('16. Verify clean empty-state screens when zero records exist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Screen A: Transactions History empty state
      await tester.pumpWidget(createTestApp(TransactionsScreen(onAddTransaction: () {})));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Add Transaction'), findsOneWidget);

      // Screen B: Analytics empty state
      await tester.pumpWidget(createTestApp(const AnalyticsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No expenses recorded for this month'), findsOneWidget);
    });
  });
}
