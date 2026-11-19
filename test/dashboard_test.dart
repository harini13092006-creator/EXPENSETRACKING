import 'package:flutter_test/flutter_test.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

void main() {
  group('DashboardProvider & Calculation Tests', () {
    late DashboardProvider provider;

    setUp(() {
      provider = DashboardProvider();
    });

    test('Formula Test: Remaining Budget = Monthly Budget - Total Expenses', () {
      final summary = provider.currentMonthSummary;

      // Verify the required formula is strictly respected
      expect(
        summary.remainingBudget,
        closeTo(summary.monthlyBudget - summary.totalExpenses, 0.001),
      );

      // Verify utilization percentage calculation
      final expectedPercent = (summary.totalExpenses / summary.monthlyBudget) * 100;
      expect(
        summary.budgetUtilizationPercentage,
        closeTo(expectedPercent, 0.001),
      );
    });

    test('Category Spending contains all 9 required categories', () {
      final summary = provider.currentMonthSummary;
      final categoryIds = summary.categorySpendings.map((c) => c.category.id).toList();

      expect(categoryIds, containsAll([
        'food',
        'transport',
        'shopping',
        'entertainment',
        'healthcare',
        'education',
        'bills',
        'travel',
        'other',
      ]));
    });

    test('Recent transactions contains at most 5 latest items', () {
      final summary = provider.currentMonthSummary;
      expect(summary.recentTransactions.length, lessThanOrEqualTo(5));

      // Check sorted descending by date
      for (int i = 0; i < summary.recentTransactions.length - 1; i++) {
        expect(
          summary.recentTransactions[i].date.isAfter(summary.recentTransactions[i + 1].date) ||
              summary.recentTransactions[i].date.isAtSameMomentAs(summary.recentTransactions[i + 1].date),
          isTrue,
        );
      }
    });

    test('Month switching recalculates summary dynamically', () {
      final novSummary = provider.currentMonthSummary;
      expect(novSummary.month.month, 11);

      // Switch to previous month (October 2026)
      provider.previousMonth();
      final octSummary = provider.currentMonthSummary;
      expect(octSummary.month.month, 10);
      expect(octSummary.totalExpenses, isNot(novSummary.totalExpenses));

      // Formula must hold true for October
      expect(
        octSummary.remainingBudget,
        closeTo(octSummary.monthlyBudget - octSummary.totalExpenses, 0.001),
      );

      // Switch to next month twice (December 2026)
      provider.nextMonth(); // November
      provider.nextMonth(); // December
      final decSummary = provider.currentMonthSummary;
      expect(decSummary.month.month, 12);
      expect(decSummary.totalExpenses, 0.0);
      expect(decSummary.remainingBudget, decSummary.monthlyBudget);
    });

    test('Adding a transaction dynamically updates summary and remaining budget', () {
      final initialSummary = provider.currentMonthSummary;
      final initialRemaining = initialSummary.remainingBudget;
      final initialExpenses = initialSummary.totalExpenses;

      final newExpense = TransactionModel(
        id: 'new_tx_1',
        description: 'New Book Purchase',
        amount: 50.00,
        date: DateTime(2026, 11, 17, 16, 0),
        categoryId: CategoryCatalog.education.id,
        isExpense: true,
      );

      provider.addTransaction(newExpense);

      final updatedSummary = provider.currentMonthSummary;
      expect(updatedSummary.totalExpenses, closeTo(initialExpenses + 50.00, 0.001));
      expect(updatedSummary.remainingBudget, closeTo(initialRemaining - 50.00, 0.001));
      expect(updatedSummary.recentTransactions.first.description, 'New Book Purchase');
    });
  });
}
