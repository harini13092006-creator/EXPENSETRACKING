import 'package:expensetracker/data/database/database_helper.dart';
import 'package:expensetracker/data/models/budget_model.dart';

/// Abstract contract for Budget repository data access.
abstract class BudgetRepository {
  Future<BudgetModel?> getBudget(int month, int year);
  Future<int> setBudget(BudgetModel budget);
  Future<List<BudgetModel>> getAllBudgets();
}

/// Concrete repository implementation powered by SQLite DatabaseHelper.
class BudgetRepositoryImpl implements BudgetRepository {
  final DatabaseHelper _databaseHelper;

  BudgetRepositoryImpl({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  @override
  Future<BudgetModel?> getBudget(int month, int year) async {
    return await _databaseHelper.getBudget(month, year);
  }

  @override
  Future<int> setBudget(BudgetModel budget) async {
    return await _databaseHelper.insertOrUpdateBudget(budget);
  }

  @override
  Future<List<BudgetModel>> getAllBudgets() async {
    return await _databaseHelper.getAllBudgets();
  }
}
