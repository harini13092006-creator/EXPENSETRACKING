import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:expensetracker/core/constants/category_constants.dart';
import 'package:expensetracker/data/models/budget_model.dart';
import 'package:expensetracker/data/models/category_spending_model.dart';
import 'package:expensetracker/data/models/monthly_summary_model.dart';
import 'package:expensetracker/data/models/transaction_model.dart';
import 'package:expensetracker/data/repositories/budget_repository.dart';
import 'package:expensetracker/data/repositories/transaction_repository.dart';
import 'package:expensetracker/data/repositories/firestore_expense_repository.dart';
import 'package:expensetracker/data/models/user_profile.dart';

/// Historical monthly trend data for analytics charts.
class MonthlyTrendData {
  final DateTime month;
  final String monthLabel;
  final double totalExpenses;
  final double totalIncome;
  final double netSavings;
  final double budget;

  const MonthlyTrendData({
    required this.month,
    required this.monthLabel,
    required this.totalExpenses,
    required this.totalIncome,
    required this.netSavings,
    required this.budget,
  });
}

/// Provider responsible for managing dashboard state, selected month,
/// budget tracking, dynamic calculations, and SQLite persistence.
class DashboardProvider extends ChangeNotifier {
  final TransactionRepository _repository;
  final BudgetRepository _budgetRepository;
  final FirestoreExpenseRepository? _firestore;
  StreamSubscription<UserProfile?>? _profileSubscription;
  StreamSubscription<List<TransactionModel>>? _transactionsSubscription;
  StreamSubscription<List<BudgetModel>>? _budgetsSubscription;
  StreamSubscription<List<CategoryItem>>? _categoriesSubscription;
  StreamSubscription<Map<String, dynamic>?>? _preferencesSubscription;

  UserProfile? _profile;
  List<CategoryItem> _categories = [];
  String? _loadError;
  bool _categoriesLoaded = false;
  bool _preferencesLoaded = false;
  String _savedThemeMode = 'system';
  bool _notificationsEnabled = true;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  double _defaultMonthlyBudget = 0;
  double? _loadedBudget;
  bool _isLoading = false;
  int _cloudLoadGeneration = 0;

  final List<TransactionModel> _transactions = [];
  final Map<String, double> _budgetsByMonth = {};

  DashboardProvider({
    TransactionRepository? repository,
    BudgetRepository? budgetRepository,
  }) : this._(repository: repository, budgetRepository: budgetRepository);

  DashboardProvider.forUser(String uid)
    : this._(firestore: FirestoreExpenseRepository(uid: uid));

  DashboardProvider._({
    TransactionRepository? repository,
    BudgetRepository? budgetRepository,
    FirestoreExpenseRepository? firestore,
  }) : _firestore = firestore,
       _repository =
           repository ??
           (firestore == null
               ? TransactionRepositoryImpl()
               : FirestoreTransactionRepository(firestore)),
       _budgetRepository =
           budgetRepository ??
           (firestore == null
               ? BudgetRepositoryImpl()
               : FirestoreBudgetRepository(firestore)) {
    if (firestore == null) {
      loadTransactions();
    } else {
      _listenForUserData();
    }
  }

  DateTime get selectedMonth => _selectedMonth;
  String get uid => _firestore?.uid ?? '';
  String get fullName => _profile?.fullName ?? '';
  String get email =>
      _profile?.email ?? FirebaseAuth.instance.currentUser?.email ?? '';
  String? get photoUrl => _profile?.photoUrl;
  String get currencyCode => _profile?.currencyCode ?? 'INR';
  double get savingsGoal => _profile?.savingsGoal ?? 0;
  double get profileMonthlyIncome => _profile?.monthlyIncome ?? 0;
  String get regularExpenses => _profile?.regularExpenses ?? '';
  String get primaryGoal => _profile?.primaryGoal ?? '';
  String? get loadError => _loadError;
  bool get isCloudBacked => _firestore != null;
  bool get categoriesLoaded => _categoriesLoaded;
  bool get preferencesLoaded => _preferencesLoaded;
  String get savedThemeMode => _savedThemeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  List<CategoryItem> get categories => List.unmodifiable(
    _categories.isEmpty ? CategoryCatalog.allCategories : _categories,
  );
  List<CategoryItem> get expenseCategories =>
      categories.where((category) => category.isExpense).toList();
  List<CategoryItem> get incomeCategories =>
      categories.where((category) => !category.isExpense).toList();
  String get currencySymbol =>
      NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
  double get monthlyBudget {
    final key = _monthKey(_selectedMonth.year, _selectedMonth.month);
    return _budgetsByMonth[key] ?? _loadedBudget ?? _defaultMonthlyBudget;
  }

  bool get isLoading => _isLoading;

  List<TransactionModel> get allTransactions =>
      List.unmodifiable(_transactions);

  String _monthKey(int year, int month) => '${year}_$month';

  void _listenForUserData() {
    final generation = ++_cloudLoadGeneration;
    _isLoading = true;
    notifyListeners();
    Future<void>(() async {
      try {
        final cloud = _firestore!;
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || user.uid != cloud.uid) {
          throw StateError('Sign in again to load this account.');
        }
        await cloud.ensureProfile(user);
        if (generation != _cloudLoadGeneration) return;
        _profileSubscription = cloud.watchProfile().listen(
          (profile) {
            _profile = profile;
            if (profile != null) {
              _defaultMonthlyBudget = profile.monthlyBudget;
              final selectedKey = _monthKey(
                _selectedMonth.year,
                _selectedMonth.month,
              );
              if (!_budgetsByMonth.containsKey(selectedKey)) {
                _loadedBudget = _defaultMonthlyBudget;
              }
            }
            _loadError = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) => _handleCloudError(
            error,
            stackTrace,
            'profile.watch',
            'users/${cloud.uid}',
          ),
        );
        _transactionsSubscription = cloud.watchTransactions().listen(
          (transactions) {
            _transactions
              ..clear()
              ..addAll(transactions);
            _loadError = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) => _handleCloudError(
            error,
            stackTrace,
            'transactions.watch',
            'users/${cloud.uid}/transactions',
          ),
        );
        _budgetsSubscription = cloud.watchBudgets().listen(
          (budgets) {
            _budgetsByMonth
              ..clear()
              ..addEntries(
                budgets.map(
                  (budget) => MapEntry(
                    _monthKey(budget.year, budget.month),
                    budget.amount,
                  ),
                ),
              );
            _loadedBudget =
                _budgetsByMonth[_monthKey(
                  _selectedMonth.year,
                  _selectedMonth.month,
                )] ??
                _defaultMonthlyBudget;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) => _handleCloudError(
            error,
            stackTrace,
            'budgets.watch',
            'users/${cloud.uid}/budgets',
          ),
        );
        _categoriesSubscription = cloud.watchCategories().listen(
          (categories) {
            _categories = categories;
            _categoriesLoaded = true;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) => _handleCloudError(
            error,
            stackTrace,
            'categories.watch',
            'users/${cloud.uid}/categories',
          ),
        );
        _preferencesSubscription = cloud.watchPreferences().listen(
          (settings) {
            if (settings != null) {
              final mode = settings['themeMode'] as String? ?? 'system';
              _savedThemeMode = ['system', 'light', 'dark'].contains(mode)
                  ? mode
                  : 'system';
              _notificationsEnabled =
                  settings['notificationsEnabled'] as bool? ?? true;
            }
            _preferencesLoaded = true;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) => _handleCloudError(
            error,
            stackTrace,
            'preferences.watch',
            'users/${cloud.uid}/settings/preferences',
          ),
        );
      } catch (error, stackTrace) {
        if (generation == _cloudLoadGeneration) {
          _handleCloudError(
            error,
            stackTrace,
            'dashboard.initialize',
            'users/${_firestore?.uid ?? 'unknown'}',
          );
        }
      } finally {
        if (generation == _cloudLoadGeneration) {
          _isLoading = false;
          notifyListeners();
        }
      }
    });
  }

  String _requestReachedFirebase(FirebaseException error) =>
      switch (error.code) {
        'permission-denied' ||
        'unauthenticated' ||
        'not-found' ||
        'failed-precondition' ||
        'invalid-argument' ||
        'resource-exhausted' => 'yes',
        'network-request-failed' => 'no',
        _ => 'unknown',
      };

  void _handleCloudError(
    Object error, [
    StackTrace? stackTrace,
    String operation = 'dashboard',
    String path = 'users',
  ]) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'none';
    final projectId = Firebase.apps.isEmpty
        ? 'unavailable'
        : Firebase.app().options.projectId;
    if (error is FirebaseException) {
      debugPrint(
        '[Dashboard] operation=$operation failed uid=$uid projectId=$projectId path=$path plugin=${error.plugin} FirebaseException.code=${error.code} message=${error.message ?? 'none'} requestReachedFirebase=${_requestReachedFirebase(error)}${stackTrace == null ? '' : '\n$stackTrace'}',
      );
      final details = error.message?.toLowerCase() ?? '';
      _loadError =
          details.contains('service_disabled') ||
              details.contains('cloud firestore api has not been used')
          ? 'Cloud Firestore is disabled for this Firebase project. Enable the Firestore API, then retry.'
          : switch (error.code) {
              'permission-denied' =>
                'Firebase denied $operation at $path. Check the deployed Firestore rules.',
              'unauthenticated' =>
                'Your Firebase sign-in expired. Sign in again and retry.',
              'unavailable' || 'network-request-failed' => 'Firebase is temporarily unavailable. Check your connection and retry.',
              _ =>
                'Could not load dashboard data (${error.code}). ${error.message ?? ''}'
                    .trim(),
            };
    } else {
      debugPrint(
        '[Dashboard] operation=$operation failed uid=$uid projectId=$projectId path=$path type=${error.runtimeType} message=$error requestReachedFirebase=unknown${stackTrace == null ? '' : '\n$stackTrace'}',
      );
      _loadError = error is StateError
          ? error.message
          : 'Could not load dashboard data.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> retryCloudLoad() async {
    if (_firestore == null) {
      await loadTransactions();
      return;
    }
    ++_cloudLoadGeneration;
    await Future.wait([
      _profileSubscription?.cancel() ?? Future<void>.value(),
      _transactionsSubscription?.cancel() ?? Future<void>.value(),
      _budgetsSubscription?.cancel() ?? Future<void>.value(),
      _categoriesSubscription?.cancel() ?? Future<void>.value(),
      _preferencesSubscription?.cancel() ?? Future<void>.value(),
    ]);
    _profileSubscription = null;
    _transactionsSubscription = null;
    _budgetsSubscription = null;
    _categoriesSubscription = null;
    _preferencesSubscription = null;
    _loadError = null;
    _listenForUserData();
  }

  Future<void> updateProfile({
    String? fullName,
    String? currencyCode,
    double? savingsGoal,
    String? photoUrl,
  }) async {
    final cloud = _firestore;
    if (cloud == null) return;
    await cloud.updateProfile(
      fullName: fullName ?? this.fullName,
      currencyCode: currencyCode ?? this.currencyCode,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  Future<void> updateCategory(
    CategoryItem category, {
    double monthlyBudget = 0,
  }) async {
    if (_firestore == null) return;
    await _firestore!.saveCategory(category, monthlyBudget: monthlyBudget);
  }

  Future<void> deleteCategory(String id) async {
    if (_firestore == null) return;
    await _firestore!.deleteCategory(id);
  }

  Future<void> setCategoryBudget(String id, double amount) async {
    if (_firestore == null) return;
    await _firestore!.updateCategoryBudget(id, amount);
  }

  Future<void> savePreferences({
    required String themeMode,
    required bool notificationsEnabled,
  }) async {
    if (_firestore == null) return;
    _savedThemeMode = themeMode;
    _notificationsEnabled = notificationsEnabled;
    _preferencesLoaded = true;
    notifyListeners();
    await _firestore!.savePreferences(
      currencyCode: currencyCode,
      themeMode: themeMode,
      notificationsEnabled: notificationsEnabled,
    );
  }

  Future<void> updateEmail(String email) async {
    final user = FirebaseAuth.instance.currentUser;
    if (_firestore == null || user == null) return;
    await user.verifyBeforeUpdateEmail(email.trim());
  }

  Future<void> updatePassword(String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No signed-in user.');
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount({String? password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (_firestore == null || user == null || user.uid != _firestore!.uid)
      return;
    final providers = user.providerData
        .map((provider) => provider.providerId)
        .toSet();
    if (providers.contains('password')) {
      if (password == null || user.email == null)
        throw FirebaseAuthException(code: 'reauthentication-required');
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } else {
      final AuthProvider provider = providers.contains('google.com')
          ? GoogleAuthProvider()
          : providers.contains('facebook.com')
          ? FacebookAuthProvider()
          : providers.contains('apple.com')
          ? AppleAuthProvider()
          : MicrosoftAuthProvider();
      if (kIsWeb) {
        await user.reauthenticateWithPopup(provider);
      } else {
        await user.reauthenticateWithProvider(provider);
      }
    }
    await _firestore!.deleteProfilePhoto();
    await _firestore!.deleteAllUserData();
    await user.delete();
  }

  /// Retrieve budget for a specific month and year
  double getBudgetForMonth(int month, int year) {
    final key = _monthKey(year, month);
    return _budgetsByMonth[key] ?? _defaultMonthlyBudget;
  }

  /// Load the local repository only. Signed-in app sessions use realtime listeners.
  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final loaded = await _repository.getAllTransactions();
      _transactions.clear();
      _transactions.addAll(loaded);

      final budgets = await _budgetRepository.getAllBudgets();
      for (final b in budgets) {
        _budgetsByMonth[_monthKey(b.year, b.month)] = b.amount;
      }

      final currentKey = _monthKey(_selectedMonth.year, _selectedMonth.month);
      if (_budgetsByMonth.containsKey(currentKey)) {
        _loadedBudget = _budgetsByMonth[currentKey];
      } else {
        _loadedBudget = _defaultMonthlyBudget;
      }
    } catch (e) {
      debugPrint('Error loading transactions from SQLite: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dynamically computes monthly summary for the currently selected month.
  MonthlySummaryModel get currentMonthSummary =>
      getSummaryForMonth(_selectedMonth);

  /// Dynamically computes monthly summary for any target month and year.
  MonthlySummaryModel getSummaryForMonth(DateTime targetMonth) {
    final year = targetMonth.year;
    final month = targetMonth.month;

    // Filter transactions for target year and month
    final monthTransactions = _transactions.where((t) {
      return t.date.year == year && t.date.month == month;
    }).toList();

    double totalIncome = 0.0;
    double totalExpenses = 0.0;

    final expenseCategories = this.expenseCategories;
    final Map<String, double> categoryExpenseTotals = {
      for (final cat in expenseCategories) cat.id: 0.0,
    };

    for (final t in monthTransactions) {
      if (t.isExpense) {
        totalExpenses += t.amount;
        categoryExpenseTotals[t.categoryId] =
            (categoryExpenseTotals[t.categoryId] ?? 0.0) + t.amount;
      } else {
        totalIncome += t.amount;
      }
    }

    // Build category spending list
    final List<CategorySpendingModel> categorySpendings = [];
    for (final category in expenseCategories) {
      final amount = categoryExpenseTotals[category.id] ?? 0.0;
      final percentage = totalExpenses > 0 ? (amount / totalExpenses) : 0.0;
      categorySpendings.add(
        CategorySpendingModel(
          category: category,
          amount: amount,
          percentage: category.monthlyBudget > 0
              ? amount / category.monthlyBudget
              : percentage,
          usesCategoryBudget: category.monthlyBudget > 0,
        ),
      );
    }

    // Sort category spendings descending by amount
    categorySpendings.sort((a, b) => b.amount.compareTo(a.amount));

    // Get latest 5 transactions sorted descending by date
    final sortedMonthTransactions = List<TransactionModel>.from(
      monthTransactions,
    )..sort((a, b) => b.date.compareTo(a.date));

    final recentTransactions = sortedMonthTransactions.take(5).toList();
    final budget = getBudgetForMonth(month, year);

    return MonthlySummaryModel(
      month: targetMonth,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      monthlyBudget: budget,
      categorySpendings: categorySpendings,
      recentTransactions: recentTransactions,
    );
  }

  /// Dynamic historical monthly trends computed from SQLite records.
  List<MonthlyTrendData> getRecentMonthlyTrends({int monthsCount = 6}) {
    final List<MonthlyTrendData> trends = [];
    for (int i = monthsCount - 1; i >= 0; i--) {
      final d = DateTime(_selectedMonth.year, _selectedMonth.month - i, 1);
      final monthTx = _transactions.where(
        (t) => t.date.year == d.year && t.date.month == d.month,
      );
      double expenses = 0.0;
      double income = 0.0;
      for (final tx in monthTx) {
        if (tx.isExpense) {
          expenses += tx.amount;
        } else {
          income += tx.amount;
        }
      }
      final b = getBudgetForMonth(d.month, d.year);
      final label = DateFormat('MMM').format(d);
      trends.add(
        MonthlyTrendData(
          month: d,
          monthLabel: label,
          totalExpenses: expenses,
          totalIncome: income,
          netSavings: income - expenses,
          budget: b,
        ),
      );
    }
    return trends;
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _budgetsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _preferencesSubscription?.cancel();
    super.dispose();
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month, 1);
    final key = _monthKey(_selectedMonth.year, _selectedMonth.month);
    if (_budgetsByMonth.containsKey(key)) {
      _loadedBudget = _budgetsByMonth[key];
    }
    _reloadBudgetForSelectedMonth();
    notifyListeners();
  }

  void previousMonth() {
    setSelectedMonth(
      DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1),
    );
  }

  void nextMonth() {
    setSelectedMonth(
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1),
    );
  }

  Future<void> _reloadBudgetForSelectedMonth() async {
    final key = _monthKey(_selectedMonth.year, _selectedMonth.month);
    if (_budgetsByMonth.containsKey(key)) {
      _loadedBudget = _budgetsByMonth[key];
      notifyListeners();
      return;
    }

    try {
      final budget = await _budgetRepository.getBudget(
        _selectedMonth.month,
        _selectedMonth.year,
      );
      if (budget != null) {
        _budgetsByMonth[key] = budget.amount;
        _loadedBudget = budget.amount;
      } else {
        _loadedBudget = _defaultMonthlyBudget;
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Sets monthly budget for current or specified month/year and persists to SQLite database
  Future<void> setMonthlyBudget(
    double newBudget, {
    int? month,
    int? year,
  }) async {
    final targetMonth = month ?? _selectedMonth.month;
    final targetYear = year ?? _selectedMonth.year;
    final key = _monthKey(targetYear, targetMonth);
    _budgetsByMonth[key] = newBudget;

    if (targetMonth == _selectedMonth.month &&
        targetYear == _selectedMonth.year) {
      _loadedBudget = newBudget;
      _defaultMonthlyBudget = newBudget;
    }
    notifyListeners();

    try {
      await _budgetRepository.setBudget(
        BudgetModel(month: targetMonth, year: targetYear, amount: newBudget),
      );
    } catch (e) {
      debugPrint('Error updating monthly budget: $e');
    }
  }

  /// Asynchronously persists transaction into SQLite, then retrieves updated database values and refreshes dashboard
  Future<void> addTransaction(TransactionModel transaction) async {
    _transactions.insert(0, transaction);
    notifyListeners();

    try {
      await _repository.addTransaction(transaction);
      // Firestore snapshots are authoritative; avoid an extra read after writes.
      if (_firestore == null) {
        final loaded = await _repository.getAllTransactions();
        _transactions.clear();
        _transactions.addAll(loaded);
        notifyListeners();
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[Dashboard] transaction.create failed uid=${FirebaseAuth.instance.currentUser?.uid ?? 'none'} errorType=${error.runtimeType} message=$error\n$stackTrace',
      );
      _transactions.remove(transaction);
      notifyListeners();
      rethrow;
    }
  }

  /// Delete transaction from SQLite and refresh dashboard
  Future<void> deleteTransaction(dynamic id) async {
    final previous = List<TransactionModel>.from(_transactions);
    _transactions.removeWhere((t) => t.id?.toString() == id?.toString());
    notifyListeners();

    try {
      await _repository.deleteTransaction(id);
      if (_firestore == null) {
        final loaded = await _repository.getAllTransactions();
        _transactions
          ..clear()
          ..addAll(loaded);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      _transactions
        ..clear()
        ..addAll(previous);
      notifyListeners();
      rethrow;
    }
  }

  /// Update transaction in SQLite and refresh dashboard
  Future<void> updateTransaction(TransactionModel transaction) async {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    final previous = index == -1 ? null : _transactions[index];
    if (index != -1) {
      _transactions[index] = transaction;
      notifyListeners();
    }

    try {
      await _repository.updateTransaction(transaction);
      if (_firestore == null) {
        final loaded = await _repository.getAllTransactions();
        if (loaded.isNotEmpty) {
          _transactions
            ..clear()
            ..addAll(loaded);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      if (index != -1 && previous != null) _transactions[index] = previous;
      notifyListeners();
      rethrow;
    }
  }
}
