import 'package:expensetracker/data/database/database_helper.dart';
import 'package:expensetracker/data/models/transaction_model.dart';

/// Abstract contract for Transaction repository data access.
abstract class TransactionRepository {
  Future<List<TransactionModel>> getAllTransactions();
  Future<List<TransactionModel>> getMonthlyTransactions(int month, int year);
  Future<TransactionModel?> getTransactionById(int id);
  Future<int> insertTransaction(TransactionModel transaction);
  Future<void> addTransaction(TransactionModel transaction);
  Future<int> updateTransaction(TransactionModel transaction);
  Future<int> deleteTransaction(dynamic id);
  Future<Map<String, double>> getCategoryExpenseTotals(int month, int year);
  Future<Map<String, double>> getAllCategoryExpenseTotals();
}

/// Concrete repository implementation powered by SQLite DatabaseHelper.
class TransactionRepositoryImpl implements TransactionRepository {
  final DatabaseHelper _databaseHelper;

  TransactionRepositoryImpl({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  @override
  Future<List<TransactionModel>> getAllTransactions() async {
    return await _databaseHelper.getAllTransactions();
  }

  @override
  Future<List<TransactionModel>> getMonthlyTransactions(int month, int year) async {
    return await _databaseHelper.getMonthlyTransactions(month, year);
  }

  @override
  Future<TransactionModel?> getTransactionById(int id) async {
    return await _databaseHelper.getTransactionById(id);
  }

  @override
  Future<int> insertTransaction(TransactionModel transaction) async {
    return await _databaseHelper.insertTransaction(transaction);
  }

  @override
  Future<void> addTransaction(TransactionModel transaction) async {
    await _databaseHelper.insertTransaction(transaction);
  }

  @override
  Future<int> updateTransaction(TransactionModel transaction) async {
    return await _databaseHelper.updateTransaction(transaction);
  }

  @override
  Future<int> deleteTransaction(dynamic id) async {
    final int parsedId = id is int ? id : int.parse(id.toString());
    return await _databaseHelper.deleteTransaction(parsedId);
  }

  @override
  Future<Map<String, double>> getCategoryExpenseTotals(int month, int year) async {
    return await _databaseHelper.getCategoryExpenseTotals(month, year);
  }

  @override
  Future<Map<String, double>> getAllCategoryExpenseTotals() async {
    return await _databaseHelper.getAllCategoryExpenseTotals();
  }
}
