import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/data/repositories/transaction_repository.dart';
import 'package:expensetracker/features/transactions/screens/add_transaction_screen.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';

/// In-memory mock repository for isolated widget and unit testing.
class MockTransactionRepository implements TransactionRepository {
  final List<TransactionModel> _storage = [];

  @override
  Future<List<TransactionModel>> getAllTransactions() async {
    return List.from(_storage);
  }

  @override
  Future<List<TransactionModel>> getMonthlyTransactions(int month, int year) async {
    return _storage.where((t) => t.date.month == month && t.date.year == year).toList();
  }

  @override
  Future<TransactionModel?> getTransactionById(int id) async {
    final matches = _storage.where((t) => t.id == id);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<int> insertTransaction(TransactionModel transaction) async {
    final nextId = _storage.length + 1;
    final item = transaction.copyWith(id: transaction.id ?? nextId);
    _storage.add(item);
    return item.id ?? nextId;
  }

  @override
  Future<void> addTransaction(TransactionModel transaction) async {
    await insertTransaction(transaction);
  }

  @override
  Future<int> deleteTransaction(dynamic id) async {
    _storage.removeWhere((t) => t.id?.toString() == id.toString());
    return 1;
  }

  @override
  Future<int> updateTransaction(TransactionModel transaction) async {
    final index = _storage.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _storage[index] = transaction;
      return 1;
    }
    return 0;
  }

  @override
  Future<Map<String, double>> getCategoryExpenseTotals(int month, int year) async {
    final totals = <String, double>{};
    for (final t in _storage) {
      if (t.isExpense && t.date.month == month && t.date.year == year) {
        totals[t.category] = (totals[t.category] ?? 0.0) + t.amount;
      }
    }
    return totals;
  }

  @override
  Future<Map<String, double>> getAllCategoryExpenseTotals() async {
    final totals = <String, double>{};
    for (final t in _storage) {
      if (t.isExpense) {
        totals[t.category] = (totals[t.category] ?? 0.0) + t.amount;
      }
    }
    return totals;
  }
}

void main() {
  group('Add Transaction Feature Tests', () {
    late DashboardProvider provider;
    late MockTransactionRepository repository;

    setUp(() {
      repository = MockTransactionRepository();
      provider = DashboardProvider(repository: repository);
    });

    Widget createTestWidget() {
      return ChangeNotifierProvider<DashboardProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: AddTransactionScreen(),
        ),
      );
    }

    testWidgets('Renders all required form fields and default values', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check header and form fields
      expect(find.text('Add Transaction'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Description *'), findsOneWidget);
      expect(find.text('Transaction Date'), findsOneWidget);
      expect(find.text('Category *'), findsOneWidget);
      expect(find.text('Save Transaction'), findsOneWidget);

      // Default expense categories rendered
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('Healthcare'), findsOneWidget);
      expect(find.text('Education'), findsOneWidget);
      expect(find.text('Bills'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('Validates empty description and invalid amount', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap save without filling form
      await tester.ensureVisible(find.text('Save Transaction'));
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      // Form validation messages
      expect(find.text('Please enter an amount'), findsOneWidget);
      expect(find.text('Description cannot be empty'), findsOneWidget);
    });

    testWidgets('Switches to Income and displays income categories', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Income button
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      // Income categories should now be visible
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Freelance'), findsOneWidget);
      expect(find.text('Business'), findsOneWidget);
      expect(find.text('Investment'), findsOneWidget);
      expect(find.text('Gift'), findsOneWidget);
    });

    testWidgets('Successfully adds a valid expense and updates DashboardProvider', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final initialExpenses = provider.currentMonthSummary.totalExpenses;

      // Enter Amount
      await tester.enterText(find.byType(TextFormField).first, '75.50');

      // Enter Description
      await tester.enterText(find.byType(TextFormField).at(1), 'Dinner with friends');

      // Tap Transport category
      await tester.tap(find.text('Transport'));
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.text('Save Transaction'));
      await tester.tap(find.text('Save Transaction'));
      await tester.pumpAndSettle();

      // Verify Provider was updated
      expect(provider.currentMonthSummary.totalExpenses, closeTo(initialExpenses + 75.50, 0.001));
      expect(provider.allTransactions.any((t) => t.description == 'Dinner with friends'), isTrue);
    });
  });
}
