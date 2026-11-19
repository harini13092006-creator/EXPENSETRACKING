import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/data/models/budget_model.dart';
import 'package:expensetracker/data/models/monthly_summary_model.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/data/repositories/budget_repository.dart';
import 'package:expensetracker/data/repositories/transaction_repository.dart';
import 'package:expensetracker/features/analytics/screens/analytics_screen.dart';
import 'package:expensetracker/features/budget/widgets/set_budget_dialog.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

class InMemoryTxRepo implements TransactionRepository {
  final List<TransactionModel> storage;

  InMemoryTxRepo([List<TransactionModel>? initial])
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

class InMemoryBudgetRepo implements BudgetRepository {
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
  group('Budget Calculations & Analytics Models Tests', () {
    test('1. Core Budget Calculations (Total Expenses, Income, Remaining, Usage %)', () {
      final summary = MonthlySummaryModel(
        month: DateTime(2026, 11, 1),
        totalIncome: 5000.0,
        totalExpenses: 2000.0,
        monthlyBudget: 4000.0,
        categorySpendings: [],
        recentTransactions: [],
      );

      // Remaining Budget = Monthly Budget - Total Expenses
      expect(summary.remainingBudget, equals(2000.0));

      // Budget Usage Percentage = (Total Expenses / Monthly Budget) × 100
      expect(summary.budgetUsagePercentage, equals(50.0));
      expect(summary.netSavings, equals(3000.0));
      expect(summary.savingsRatePercentage, equals(60.0));
      expect(summary.isOverBudget, isFalse);
    });

    test('2. Safe handling of zero budget without division by zero', () {
      final zeroBudgetSummary = MonthlySummaryModel(
        month: DateTime(2026, 11, 1),
        totalIncome: 1000.0,
        totalExpenses: 300.0,
        monthlyBudget: 0.0,
        categorySpendings: [],
        recentTransactions: [],
      );

      // Must safely return 0.0 without crash
      expect(zeroBudgetSummary.budgetUsagePercentage, equals(0.0));
      expect(zeroBudgetSummary.budgetUtilizationRatio, equals(0.0));
      expect(zeroBudgetSummary.remainingBudget, equals(-300.0));
      expect(zeroBudgetSummary.isOverBudget, isTrue);
    });

    test('3. Budget Alert Thresholds validation', () {
      // Below 50%: Normal
      final normalSummary = MonthlySummaryModel(
        month: DateTime(2026, 11, 1),
        totalIncome: 3000.0,
        totalExpenses: 1600.0,
        monthlyBudget: 4000.0, // 40%
        categorySpendings: [],
        recentTransactions: [],
      );
      expect(normalSummary.budgetAlertStatus, equals(BudgetAlertStatus.normal));
      expect(normalSummary.budgetAlertLabel, equals('Normal'));

      // 50–80%: Moderate spending
      final moderateSummary = MonthlySummaryModel(
        month: DateTime(2026, 11, 1),
        totalIncome: 3000.0,
        totalExpenses: 2800.0,
        monthlyBudget: 4000.0, // 70%
        categorySpendings: [],
        recentTransactions: [],
      );
      expect(moderateSummary.budgetAlertStatus, equals(BudgetAlertStatus.moderate));
      expect(moderateSummary.budgetAlertLabel, equals('Moderate spending'));

      // 80–100%: Near budget limit
      final nearLimitSummary = MonthlySummaryModel(
        month: DateTime(2026, 11, 1),
        totalIncome: 3000.0,
        totalExpenses: 3600.0,
        monthlyBudget: 4000.0, // 90%
        categorySpendings: [],
        recentTransactions: [],
      );
      expect(nearLimitSummary.budgetAlertStatus, equals(BudgetAlertStatus.nearLimit));
      expect(nearLimitSummary.budgetAlertLabel, equals('Near budget limit'));

      // Above 100%: Budget exceeded
      final exceededSummary = MonthlySummaryModel(
        month: DateTime(2026, 11, 1),
        totalIncome: 3000.0,
        totalExpenses: 4500.0,
        monthlyBudget: 4000.0, // 112.5%
        categorySpendings: [],
        recentTransactions: [],
      );
      expect(exceededSummary.budgetAlertStatus, equals(BudgetAlertStatus.exceeded));
      expect(exceededSummary.budgetAlertLabel, equals('Budget exceeded'));
    });
  });

  group('DashboardProvider Budget Management & Separate Month Support', () {
    late InMemoryTxRepo txRepo;
    late InMemoryBudgetRepo budgetRepo;
    late DashboardProvider provider;

    setUp(() async {
      txRepo = InMemoryTxRepo();
      budgetRepo = InMemoryBudgetRepo();
      provider = DashboardProvider(
        repository: txRepo,
        budgetRepository: budgetRepo,
      );
      await provider.loadTransactions();
    });

    test('Allows setting and storing separate budgets for different months & years in SQLite repo', () async {
      // Set budget for November 2026 = $4,500
      await provider.setMonthlyBudget(4500.0, month: 11, year: 2026);
      expect(provider.getBudgetForMonth(11, 2026), equals(4500.0));

      // Set budget for December 2026 = $6,000
      await provider.setMonthlyBudget(6000.0, month: 12, year: 2026);
      expect(provider.getBudgetForMonth(12, 2026), equals(6000.0));

      // Verify persistence in repository
      final novBudget = await budgetRepo.getBudget(11, 2026);
      final decBudget = await budgetRepo.getBudget(12, 2026);
      expect(novBudget?.amount, equals(4500.0));
      expect(decBudget?.amount, equals(6000.0));

      // Switching months loads the specific month's budget
      provider.setSelectedMonth(DateTime(2026, 12, 1));
      expect(provider.monthlyBudget, equals(6000.0));

      provider.setSelectedMonth(DateTime(2026, 11, 1));
      expect(provider.monthlyBudget, equals(4500.0));
    });

    test('Dynamic calculations update upon adding, updating, and deleting transactions', () async {
      await provider.setMonthlyBudget(2000.0, month: 11, year: 2026);
      provider.setSelectedMonth(DateTime(2026, 11, 1));

      // Initial state: 0 expenses, 0 income
      var summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(0.0));
      expect(summary.remainingBudget, equals(2000.0));
      expect(summary.budgetAlertStatus, equals(BudgetAlertStatus.normal));

      // 1. Add Food Expense $600
      await provider.addTransaction(
        TransactionModel(
          id: 101,
          description: 'Weekly Groceries',
          amount: 600.0,
          date: DateTime(2026, 11, 5),
          category: CategoryCatalog.food.id,
          type: 'expense',
        ),
      );

      summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(600.0));
      expect(summary.remainingBudget, equals(1400.0)); // 2000 - 600
      expect(summary.budgetUsagePercentage, equals(30.0)); // (600 / 2000) * 100
      expect(summary.topSpendingCategory?.category.id, equals(CategoryCatalog.food.id));
      expect(summary.topSpendingCategory?.percentageDisplay, equals(100.0));

      // 2. Add Housing Expense $1,200 (Total Expense becomes $1,800 = 90% of budget)
      await provider.addTransaction(
        TransactionModel(
          id: 102,
          description: 'Apartment Rent',
          amount: 1200.0,
          date: DateTime(2026, 11, 6),
          category: CategoryCatalog.housing.id,
          type: 'expense',
        ),
      );

      summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(1800.0));
      expect(summary.remainingBudget, equals(200.0));
      expect(summary.budgetUsagePercentage, equals(90.0));
      expect(summary.budgetAlertStatus, equals(BudgetAlertStatus.nearLimit));
      expect(summary.topSpendingCategory?.category.id, equals(CategoryCatalog.housing.id));

      // Housing percentage: (1200 / 1800) * 100 = 66.67%
      final housingCat = summary.categorySpendings.firstWhere((c) => c.category.id == CategoryCatalog.housing.id);
      expect(housingCat.percentageDisplay, closeTo(66.67, 0.1));

      // 3. Update transaction: change rent from 1200 to 1500 (Total Expense becomes 2100 -> Budget Exceeded)
      await provider.updateTransaction(
        TransactionModel(
          id: 102,
          description: 'Apartment Rent + Parking',
          amount: 1500.0,
          date: DateTime(2026, 11, 6),
          category: CategoryCatalog.housing.id,
          type: 'expense',
        ),
      );

      summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(2100.0));
      expect(summary.remainingBudget, equals(-100.0));
      expect(summary.budgetUsagePercentage, equals(105.0));
      expect(summary.budgetAlertStatus, equals(BudgetAlertStatus.exceeded));

      // 4. Delete transaction: remove rent (Total Expense goes back to 600 -> Normal)
      await provider.deleteTransaction(102);

      summary = provider.currentMonthSummary;
      expect(summary.totalExpenses, equals(600.0));
      expect(summary.remainingBudget, equals(1400.0));
      expect(summary.budgetAlertStatus, equals(BudgetAlertStatus.normal));
    });

    test('Recent monthly trends compute correctly for fl_chart', () async {
      await provider.addTransaction(
        TransactionModel(
          id: 201,
          description: 'Past Month Expense',
          amount: 500.0,
          date: DateTime(2026, 10, 15),
          category: CategoryCatalog.food.id,
          type: 'expense',
        ),
      );

      final trends = provider.getRecentMonthlyTrends(monthsCount: 6);
      expect(trends.length, equals(6));
      expect(trends.last.month.month, equals(11)); // Selected month is November 2026
      expect(trends[4].month.month, equals(10)); // October 2026
      expect(trends[4].totalExpenses, equals(500.0));
    });
  });

  group('AnalyticsScreen & SetBudgetDialog UI Tests', () {
    late InMemoryTxRepo txRepo;
    late InMemoryBudgetRepo budgetRepo;
    late DashboardProvider provider;

    setUp(() {
      txRepo = InMemoryTxRepo([
        TransactionModel(
          id: 1,
          description: 'Supermarket Groceries',
          amount: 350.0,
          date: DateTime(2026, 11, 10),
          category: CategoryCatalog.food.id,
          type: 'expense',
        ),
        TransactionModel(
          id: 2,
          description: 'Monthly Salary',
          amount: 5000.0,
          date: DateTime(2026, 11, 1),
          category: CategoryCatalog.salary.id,
          type: 'income',
        ),
        TransactionModel(
          id: 3,
          description: 'Electric Utility Bill',
          amount: 150.0,
          date: DateTime(2026, 11, 12),
          category: CategoryCatalog.bills.id,
          type: 'expense',
        ),
      ]);
      budgetRepo = InMemoryBudgetRepo();
      budgetRepo.setBudget(BudgetModel(month: 11, year: 2026, amount: 2500.0));

      provider = DashboardProvider(
        repository: txRepo,
        budgetRepository: budgetRepo,
      );
    });

    Widget createTestApp(Widget child) {
      return ChangeNotifierProvider<DashboardProvider>.value(
        value: provider,
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('AnalyticsScreen renders dynamic charts, top category, and budget alerts', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const AnalyticsScreen()));
      await tester.pumpAndSettle();

      // 1. Verify Budget Alert Banner displays dynamically
      expect(find.byKey(const Key('budget_alert_label')), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget); // 500/2500 = 20% -> Normal
      expect(find.byKey(const Key('remaining_budget_text')), findsOneWidget);
      expect(find.text('Remaining: \$2000.00'), findsOneWidget);

      // 2. Verify Cash flow (Income vs Expense)
      expect(find.byKey(const Key('total_income_text')), findsOneWidget);
      expect(find.text('\$5000.00'), findsOneWidget);
      expect(find.byKey(const Key('total_expenses_text')), findsOneWidget);
      expect(find.text('\$500.00'), findsOneWidget);
      expect(find.byKey(const Key('net_savings_text')), findsOneWidget);
      expect(find.text('+\$4500.00'), findsOneWidget);

      // 3. Verify Top Spending Category card
      expect(find.byKey(const Key('top_spending_category_name')), findsOneWidget);
      expect(find.text(CategoryCatalog.food.name), findsWidgets);
      expect(find.text('\$350.00'), findsWidgets);

      // 4. Verify fl_chart PieChart and BarChart are rendered
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);

      // 5. Verify dynamic Category Breakdown
      expect(find.text('Spending by Category'), findsOneWidget);
    });

    testWidgets('SetBudgetDialog allows entering new budget and saves to SQLite provider', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp(const AnalyticsScreen()));
      await tester.pumpAndSettle();

      // Tap Edit Budget action
      final editButton = find.byKey(const Key('edit_budget_dialog_button'));
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Verify SetBudgetDialog opened
      expect(find.byType(SetBudgetDialog), findsOneWidget);
      expect(find.text('Monthly Budget'), findsOneWidget);

      // Enter new budget: 3500
      final textField = find.byType(TextFormField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, '3500');
      await tester.pumpAndSettle();

      // Tap Save Budget button
      final saveButton = find.byKey(const Key('save_budget_button'));
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify budget updated in provider and dialog closed
      expect(find.byType(SetBudgetDialog), findsNothing);
      expect(provider.monthlyBudget, equals(3500.0));
      expect(find.text('Remaining: \$3000.00'), findsOneWidget);
    });
  });
}
