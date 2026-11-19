import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/data/models/budget_model.dart';
import 'package:expensetracker/data/models/transaction_model.dart';

/// SQLite Database Helper for managing persistent transaction and budget storage.
///
/// Follows singleton pattern with synchronization to prevent duplicate database initialization.
/// All queries use parameterized statements and asynchronous operations.
class DatabaseHelper {
  static const String _databaseName = 'expense_tracker.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String tableTransactions = 'transactions';
  static const String tableBudgets = 'budgets';

  // Transactions columns
  static const String columnTxId = 'id';
  static const String columnTxType = 'type';
  static const String columnTxAmount = 'amount';
  static const String columnTxDescription = 'description';
  static const String columnTxCategory = 'category';
  static const String columnTxDate = 'date';
  static const String columnTxCreatedAt = 'created_at';

  // Budgets columns
  static const String columnBudgetId = 'id';
  static const String columnBudgetMonth = 'month';
  static const String columnBudgetYear = 'year';
  static const String columnBudgetAmount = 'amount';
  static const String columnBudgetCreatedAt = 'created_at';

  DatabaseHelper._init();
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;
  static Future<Database>? _dbOpenFuture;

  /// Returns the singleton Database instance, guarding against duplicate initialization.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    // Guard against concurrent openDatabase calls
    if (_dbOpenFuture != null) {
      return await _dbOpenFuture!;
    }

    _dbOpenFuture = _initDatabase();
    try {
      _database = await _dbOpenFuture!;
      return _database!;
    } catch (e, stackTrace) {
      debugPrint('Failed to initialize database: $e\n$stackTrace');
      rethrow;
    } finally {
      _dbOpenFuture = null;
    }
  }

  /// Inject custom database instance (useful for unit testing with in-memory SQLite).
  @visibleForTesting
  void setDatabase(Database db) {
    _database = db;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create transactions table
    await db.execute('''
      CREATE TABLE $tableTransactions (
        $columnTxId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTxType TEXT NOT NULL,
        $columnTxAmount REAL NOT NULL,
        $columnTxDescription TEXT NOT NULL,
        $columnTxCategory TEXT NOT NULL,
        $columnTxDate TEXT NOT NULL,
        $columnTxCreatedAt TEXT NOT NULL
      )
    ''');

    // 2. Create budgets table with UNIQUE(month, year) constraint
    await db.execute('''
      CREATE TABLE $tableBudgets (
        $columnBudgetId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnBudgetMonth INTEGER NOT NULL,
        $columnBudgetYear INTEGER NOT NULL,
        $columnBudgetAmount REAL NOT NULL,
        $columnBudgetCreatedAt TEXT NOT NULL,
        UNIQUE($columnBudgetMonth, $columnBudgetYear)
      )
    ''');

  }

  // ==========================================
  // TRANSACTION OPERATIONS
  // ==========================================

  /// Insert a new transaction into SQLite database using parameterized query.
  Future<int> insertTransaction(TransactionModel transaction) async {
    try {
      final db = await database;
      return await db.insert(
        tableTransactions,
        transaction.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      debugPrint('Error inserting transaction: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Retrieve all transactions ordered by date descending.
  Future<List<TransactionModel>> getAllTransactions() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableTransactions,
        orderBy: '$columnTxDate DESC, $columnTxId DESC',
      );
      return maps.map((map) => TransactionModel.fromMap(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error retrieving transactions: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Retrieve a single transaction by ID using parameterized query.
  Future<TransactionModel?> getTransactionById(int id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableTransactions,
        where: '$columnTxId = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return TransactionModel.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('Error retrieving transaction by id: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Update an existing transaction by ID using parameterized query.
  Future<int> updateTransaction(TransactionModel transaction) async {
    if (transaction.id == null) {
      throw ArgumentError('Cannot update transaction without an id');
    }
    try {
      final db = await database;
      return await db.update(
        tableTransactions,
        transaction.toMap(),
        where: '$columnTxId = ?',
        whereArgs: [transaction.id],
      );
    } catch (e, stackTrace) {
      debugPrint('Error updating transaction: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Delete a transaction by ID using parameterized query.
  Future<int> deleteTransaction(int id) async {
    try {
      final db = await database;
      return await db.delete(
        tableTransactions,
        where: '$columnTxId = ?',
        whereArgs: [id],
      );
    } catch (e, stackTrace) {
      debugPrint('Error deleting transaction: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Retrieve transactions for a specific month and year using parameterized query.
  Future<List<TransactionModel>> getMonthlyTransactions(int month, int year) async {
    try {
      final db = await database;
      final start = DateTime(year, month, 1).toIso8601String();
      final end = DateTime(year, month + 1, 1).toIso8601String();

      final List<Map<String, dynamic>> maps = await db.query(
        tableTransactions,
        where: '$columnTxDate >= ? AND $columnTxDate < ?',
        whereArgs: [start, end],
        orderBy: '$columnTxDate DESC, $columnTxId DESC',
      );

      return maps.map((map) => TransactionModel.fromMap(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error retrieving monthly transactions: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Retrieve category-wise expense totals for a specific month and year using parameterized query.
  Future<Map<String, double>> getCategoryExpenseTotals(int month, int year) async {
    try {
      final db = await database;
      final start = DateTime(year, month, 1).toIso8601String();
      final end = DateTime(year, month + 1, 1).toIso8601String();

      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT $columnTxCategory, SUM($columnTxAmount) AS total
        FROM $tableTransactions
        WHERE $columnTxType = ? AND $columnTxDate >= ? AND $columnTxDate < ?
        GROUP BY $columnTxCategory
      ''', ['expense', start, end]);

      final Map<String, double> categoryTotals = {};
      for (final row in result) {
        final category = row[columnTxCategory] as String;
        final total = (row['total'] as num?)?.toDouble() ?? 0.0;
        categoryTotals[category] = total;
      }
      return categoryTotals;
    } catch (e, stackTrace) {
      debugPrint('Error retrieving category expense totals: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Retrieve category-wise expense totals across all transactions using parameterized query.
  Future<Map<String, double>> getAllCategoryExpenseTotals() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT $columnTxCategory, SUM($columnTxAmount) AS total
        FROM $tableTransactions
        WHERE $columnTxType = ?
        GROUP BY $columnTxCategory
      ''', ['expense']);

      final Map<String, double> categoryTotals = {};
      for (final row in result) {
        final category = row[columnTxCategory] as String;
        final total = (row['total'] as num?)?.toDouble() ?? 0.0;
        categoryTotals[category] = total;
      }
      return categoryTotals;
    } catch (e, stackTrace) {
      debugPrint('Error retrieving all category expense totals: $e\n$stackTrace');
      rethrow;
    }
  }

  // ==========================================
  // BUDGET OPERATIONS
  // ==========================================

  /// Insert or update monthly budget using parameterized query.
  Future<int> insertOrUpdateBudget(BudgetModel budget) async {
    try {
      final db = await database;
      return await db.insert(
        tableBudgets,
        budget.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, stackTrace) {
      debugPrint('Error inserting or updating budget: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Retrieve monthly budget for given month and year using parameterized query.
  Future<BudgetModel?> getBudget(int month, int year) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableBudgets,
        where: '$columnBudgetMonth = ? AND $columnBudgetYear = ?',
        whereArgs: [month, year],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return BudgetModel.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('Error retrieving budget: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Retrieve all configured budgets.
  Future<List<BudgetModel>> getAllBudgets() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        tableBudgets,
        orderBy: '$columnBudgetYear DESC, $columnBudgetMonth DESC',
      );
      return maps.map((map) => BudgetModel.fromMap(map)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error retrieving all budgets: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Close the database instance cleanly.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
