import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:expensetracker/data/database/database_helper.dart';
import 'package:expensetracker/data/models/budget_model.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/data/repositories/budget_repository.dart';
import 'package:expensetracker/data/repositories/transaction_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SQLite DatabaseHelper & Repository Tests', () {
    late DatabaseHelper dbHelper;
    late TransactionRepository transactionRepository;
    late BudgetRepository budgetRepository;
    late Database inMemoryDb;

    setUp(() async {
      dbHelper = DatabaseHelper.instance;
      // Use an in-memory database instance for isolated test execution
      inMemoryDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${DatabaseHelper.tableTransactions} (
              ${DatabaseHelper.columnTxId} INTEGER PRIMARY KEY AUTOINCREMENT,
              ${DatabaseHelper.columnTxType} TEXT NOT NULL,
              ${DatabaseHelper.columnTxAmount} REAL NOT NULL,
              ${DatabaseHelper.columnTxDescription} TEXT NOT NULL,
              ${DatabaseHelper.columnTxCategory} TEXT NOT NULL,
              ${DatabaseHelper.columnTxDate} TEXT NOT NULL,
              ${DatabaseHelper.columnTxCreatedAt} TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE ${DatabaseHelper.tableBudgets} (
              ${DatabaseHelper.columnBudgetId} INTEGER PRIMARY KEY AUTOINCREMENT,
              ${DatabaseHelper.columnBudgetMonth} INTEGER NOT NULL,
              ${DatabaseHelper.columnBudgetYear} INTEGER NOT NULL,
              ${DatabaseHelper.columnBudgetAmount} REAL NOT NULL,
              ${DatabaseHelper.columnBudgetCreatedAt} TEXT NOT NULL,
              UNIQUE(${DatabaseHelper.columnBudgetMonth}, ${DatabaseHelper.columnBudgetYear})
            )
          ''');
        },
      );

      dbHelper.setDatabase(inMemoryDb);
      transactionRepository = TransactionRepositoryImpl(databaseHelper: dbHelper);
      budgetRepository = BudgetRepositoryImpl(databaseHelper: dbHelper);
    });

    tearDown(() async {
      await inMemoryDb.close();
    });

    test('1 & 2. Database initialization and singleton consistency', () async {
      final db1 = await dbHelper.database;
      final db2 = await dbHelper.database;
      expect(identical(db1, db2), isTrue);
      expect(db1.isOpen, isTrue);
    });

    test('3 & 4. Transaction and Budget models serialize and deserialize correctly', () {
      final now = DateTime(2026, 11, 17, 10, 0);
      final tx = TransactionModel(
        id: 1,
        type: 'expense',
        amount: 45.50,
        description: 'Coffee Beans',
        category: 'food',
        date: now,
        createdAt: now,
      );

      final map = tx.toMap();
      expect(map['id'], 1);
      expect(map['type'], 'expense');
      expect(map['amount'], 45.50);
      expect(map['description'], 'Coffee Beans');
      expect(map['category'], 'food');

      final reconstructedTx = TransactionModel.fromMap(map);
      expect(reconstructedTx.id, 1);
      expect(reconstructedTx.amount, 45.50);
      expect(reconstructedTx.isExpense, isTrue);
      expect(reconstructedTx.categoryItem.id, 'food');

      final budget = BudgetModel(
        id: 1,
        month: 11,
        year: 2026,
        amount: 3500.0,
        createdAt: now,
      );

      final budgetMap = budget.toMap();
      expect(budgetMap['month'], 11);
      expect(budgetMap['year'], 2026);
      expect(budgetMap['amount'], 3500.0);

      final reconstructedBudget = BudgetModel.fromMap(budgetMap);
      expect(reconstructedBudget.amount, 3500.0);
      expect(reconstructedBudget.month, 11);
    });

    test('5 & 6. Insert transaction and retrieve transactions (auto-increment id)', () async {
      final tx1 = TransactionModel(
        type: 'expense',
        amount: 120.0,
        description: 'Weekly Groceries',
        category: 'food',
        date: DateTime(2026, 11, 10, 12, 0),
      );

      final tx2 = TransactionModel(
        type: 'income',
        amount: 3000.0,
        description: 'Paycheck',
        category: 'salary',
        date: DateTime(2026, 11, 15, 9, 0),
      );

      final id1 = await dbHelper.insertTransaction(tx1);
      final id2 = await dbHelper.insertTransaction(tx2);

      expect(id1, greaterThan(0));
      expect(id2, greaterThan(id1));

      final all = await dbHelper.getAllTransactions();
      expect(all.length, 2);
      expect(all.first.description, 'Paycheck'); // Ordered by date descending
      expect(all.first.type, 'income');
      expect(all.last.description, 'Weekly Groceries');

      // Test get by ID
      final single = await dbHelper.getTransactionById(id1);
      expect(single, isNotNull);
      expect(single!.id, id1);
      expect(single.description, 'Weekly Groceries');
    });

    test('7. Update transaction persists changes', () async {
      final tx = TransactionModel(
        type: 'expense',
        amount: 50.0,
        description: 'Old Description',
        category: 'shopping',
        date: DateTime(2026, 11, 5, 14, 0),
      );

      final id = await dbHelper.insertTransaction(tx);
      final saved = await dbHelper.getTransactionById(id);

      final updated = saved!.copyWith(
        amount: 75.0,
        description: 'Updated Description',
      );

      final count = await dbHelper.updateTransaction(updated);
      expect(count, 1);

      final reloaded = await dbHelper.getTransactionById(id);
      expect(reloaded!.amount, 75.0);
      expect(reloaded.description, 'Updated Description');
    });

    test('8. Delete transaction removes record from database', () async {
      final tx = TransactionModel(
        type: 'expense',
        amount: 30.0,
        description: 'Temporary Item',
        category: 'other',
        date: DateTime(2026, 11, 8),
      );

      final id = await dbHelper.insertTransaction(tx);
      expect(await dbHelper.getTransactionById(id), isNotNull);

      final deletedCount = await dbHelper.deleteTransaction(id);
      expect(deletedCount, 1);
      expect(await dbHelper.getTransactionById(id), isNull);
    });

    test('9. Retrieve monthly transactions filters accurately by month and year', () async {
      // November 2026 transaction
      await dbHelper.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 100.0,
        description: 'Nov Expense 1',
        category: 'bills',
        date: DateTime(2026, 11, 2),
      ));
      await dbHelper.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 50.0,
        description: 'Nov Expense 2',
        category: 'food',
        date: DateTime(2026, 11, 20),
      ));

      // October 2026 transaction
      await dbHelper.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 200.0,
        description: 'Oct Expense',
        category: 'travel',
        date: DateTime(2026, 10, 15),
      ));

      // December 2026 transaction
      await dbHelper.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 300.0,
        description: 'Dec Expense',
        category: 'shopping',
        date: DateTime(2026, 12, 1),
      ));

      final novTransactions = await dbHelper.getMonthlyTransactions(11, 2026);
      expect(novTransactions.length, 2);
      expect(novTransactions.map((t) => t.description), containsAll(['Nov Expense 1', 'Nov Expense 2']));

      final octTransactions = await dbHelper.getMonthlyTransactions(10, 2026);
      expect(octTransactions.length, 1);
      expect(octTransactions.first.description, 'Oct Expense');

      final emptyMonth = await dbHelper.getMonthlyTransactions(1, 2025);
      expect(emptyMonth.isEmpty, isTrue);
    });

    test('10. Retrieve category-wise expense totals aggregates by category', () async {
      // Insert expenses across various categories
      await dbHelper.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 100.0,
        description: 'Dinner',
        category: 'food',
        date: DateTime(2026, 11, 5),
      ));
      await dbHelper.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 50.0,
        description: 'Lunch',
        category: 'food',
        date: DateTime(2026, 11, 6),
      ));
      await dbHelper.insertTransaction(TransactionModel(
        type: 'expense',
        amount: 80.0,
        description: 'Train pass',
        category: 'transport',
        date: DateTime(2026, 11, 7),
      ));
      // Income should not be included in expense totals
      await dbHelper.insertTransaction(TransactionModel(
        type: 'income',
        amount: 2000.0,
        description: 'Salary',
        category: 'salary',
        date: DateTime(2026, 11, 1),
      ));

      final totals = await dbHelper.getCategoryExpenseTotals(11, 2026);
      expect(totals['food'], 150.0);
      expect(totals['transport'], 80.0);
      expect(totals.containsKey('salary'), isFalse);
    });

    test('11. Insert, update, and retrieve monthly budgets', () async {
      // Initial insert
      final budget = BudgetModel(
        month: 11,
        year: 2026,
        amount: 4000.0,
      );

      final insertId = await budgetRepository.setBudget(budget);
      expect(insertId, greaterThan(0));

      final fetched = await budgetRepository.getBudget(11, 2026);
      expect(fetched, isNotNull);
      expect(fetched!.amount, 4000.0);
      expect(fetched.month, 11);
      expect(fetched.year, 2026);

      // Update same month/year budget (conflictAlgorithm replace)
      final updatedBudget = fetched.copyWith(amount: 4500.0);
      await budgetRepository.setBudget(updatedBudget);

      final reloaded = await budgetRepository.getBudget(11, 2026);
      expect(reloaded!.amount, 4500.0);

      // Non-existent budget returns null
      final missing = await budgetRepository.getBudget(5, 2025);
      expect(missing, isNull);
    });

    test('Repository methods correctly delegate to DatabaseHelper', () async {
      await transactionRepository.addTransaction(TransactionModel(
        type: 'expense',
        amount: 40.0,
        description: 'Cinema',
        category: 'entertainment',
        date: DateTime(2026, 11, 12),
      ));

      final list = await transactionRepository.getAllTransactions();
      expect(list.length, 1);
      expect(list.first.description, 'Cinema');

      final totals = await transactionRepository.getCategoryExpenseTotals(11, 2026);
      expect(totals['entertainment'], 40.0);

      await transactionRepository.deleteTransaction(list.first.id);
      final remaining = await transactionRepository.getAllTransactions();
      expect(remaining.isEmpty, isTrue);
    });

    test('Updating transaction without ID throws ArgumentError', () async {
      final invalidTx = TransactionModel(
        type: 'expense',
        amount: 10.0,
        description: 'No ID',
        category: 'other',
        date: DateTime.now(),
      );

      expect(() => dbHelper.updateTransaction(invalidTx), throwsArgumentError);
    });
  });
}
